package Text::TogoAnnotator;

# Yasunori Yamamoto / Database Center for Life Science
# -- 変更履歴 --
# * 2013.11.28 辞書ファイル仕様変更による。
# 市川さん>宮澤さんの後任が記載するルールを変えたので、正解データとしてngram掛けるのは、第3タブが○になっているもの、だけではなく、「delとRNA以外」としてください。
# * 2013.12.19 前後の"の有無の他に、出典を示す[nite]的な文字の後に"があるものと前に"があるものがあって全てに対応していなかったことに対応。
# * 2014.06.12 モジュール化
# getScore関数内で//オペレーターを使用しているため、Perlバージョンが5.10以降である必要がある。
# * 2014.09.19 14/7/23 リクエストに対応
# 1. 既に正解辞書に完全一致するエントリーがある場合は、そのままにする。
# 2. "subunit", "domain protein", "family protein" などがあり、辞書中にエントリーが無い場合は、そのままにする。
# * 2014.11.6
# 「辞書で"del"が付いているものは、人の目で確認することが望ましいという意味です。」とのコメントを受け、出力で明示するようにした。
# 具体的には、result:$query, match:"del", info:"Human check preferable" が返る。
# ハイフンの有無だけでなく空白の有無も問題を生じさせうるので、全ての空白を取り除く処理を加えてみた。
# * 2014.11.7
# Bag::Similarity::Cosineモジュールの利用で実際のcosine距離を取得してみる。
# なお、simstringには距離を取得する機能はない。
# n-gramの値はsimstringと同じ値を適用。
# "fragment"をavoid_cs_termsに追加。
# * 2014.11.21
# スコアの並び替えについては、クエリ中の語が含まれる候補を優先し、続いてcosine距離を考慮する方針に変更。
# * 2016.3.16
# exもしくはcsの際の結果のみを配列に含むresult_arrayを追加。
# * 2016.5.10
# 辞書にg列（curated）とh列（note）があることを想定した修正。
# 辞書ファイルの名前が.gzで終る場合は、gzip圧縮されたファイルとして扱い、展開する仕様に変更。
# * 2016.7.8
# Before -> After、After -> Curated ではなく、Curated辞書の書き換え前エントリをTogoAnnotator辞書のBeforeに含めて、それを優先されるようにする（完全一致のみ）。
# https://bitbucket.org/yayamamo/togoannotator/issues/3/curated
# なお、マッチさせるときには大文字小文字の違いを無視する。
# * 2016.10.13
# 酵素名辞書とマッチするデフィニションは優先順位を高めるようにした。
# 英語表記を米語表記に変換するようにした。
# * 2016.10.28
# Locus tagのプレフィックスか、EMBLから取得したLocus tagにマッチする場合には、その旨infoに記述する仕様に変更。
# * 2016.12.22
# UniProtのReviewed=trueであるタンパク質エントリのencodedByで結ばれる遺伝子のprefLabelを利用し、それに入力された文字がマッチした場合にはその旨infoに記述する仕様に変更。
# Pfamのファミリーネームに入力された文字列がマッチした場合にはその旨infoに記述する仕様に変更。
# * 2017.4.28
# Elasticsearchに対応。
# * 2017.5.18
# Elasticsearchへのデータのロード用ルーチン追加
# histogramのストアとロード対応（Sereal::Encoder/Decoderを利用）
# * 2018.1.16
# Locusタグ等にマッチさせる対象を$resultから$oqへ。
# * 2018.8.15
# White/Black List対応
# * 2018.11.26
# 変数名について、小文字化した$queryを$lcqueryに、$lc_queryを$lcb4queryに。
#

use warnings;
use strict;
use utf8;
use Fatal qw/open/;
use open qw/:utf8/;
use File::Path 'mkpath';
use File::Basename;
use Bag::Similarity::Cosine;
use String::Trim;
use simstring;
use PerlIO::gzip;
use Lingua::EN::ABC qw/b2a/;
use Text::Match::FastAlternatives;
use Search::Elasticsearch;
use Digest::MD5 qw/md5_hex/;
use Sereal::Encoder qw/sereal_encode_with_object/;
use Sereal::Decoder qw/sereal_decode_with_object/;
use File::Slurp;
use Encode;

my ($sysroot, $niteAll, $curatedDict, $enzymeDict, $locustag_prefix_name, $embl_locustag_name, $gene_symbol_name, $family_name, $esearch);
my ($nitealldb_after_name, $nitealldb_before_name);
my ($niteall_after_cs_db, $niteall_before_cs_db);
my ($white_list, $black_list);
my ($cos_threshold, $e_threashold, $cs_max, $n_gram, $cosine_object, $ignore_chars, $locustag_prefix_matcher, $embl_locustag_matcher, $gene_symbol_matcher, $family_name_matcher, $white_list_matcher, $black_list_matcher);
my ($histogram, $useCurrentDict, $md5dname);
my ($namespace, $eslogfh);

my (
    @sp_words,      # マッチ対象から外すが、マッチ処理後は元に戻して結果に表示させる語群。
    @avoid_cs_terms # コサイン距離を用いた類似マッチの対象にはしない文字列群。種々の辞書に完全一致しない場合はno_hitとする。
    );
my (
    %negative_min_words,  # コサイン距離を用いた類似マッチではクエリと辞書中のエントリで文字列としては類似していても、両者の間に共通に出現する語が無い場合がある。
                          # その場合、共通に出現する語がある辞書中エントリを優先させる処理をしているが、本処理が逆効果となってしまう語がここに含まれる。
    %name_provenance,     # 変換後デフィニションの由来。
    %curatedHash,         # curated辞書のエントリ（キーは小文字化する）
    %enzymeHash           # 酵素辞書のエントリ（小文字化する）
    );
my ($minfreq, $minword, $ifhit, $cosdist);

sub init {
    my $_this = shift;
    $cos_threshold = shift; # cosine距離で類似度を測る際に用いる閾値。この値以上類似している場合は変換対象の候補とする。
    $e_threashold  = shift; # E列での表現から候補を探す場合、辞書中での最大出現頻度がここで指定する数未満の場合のもののみを対象とする。
    $cs_max        = shift; # 複数表示する候補が在る場合の最大表示数
    $n_gram        = shift; # N-gram
    $sysroot       = shift; # 辞書や作業用ファイルを生成するディレクトリ
    $niteAll       = shift; # 辞書名
    $curatedDict   = shift; # curated辞書名（形式は同一）
    $useCurrentDict= shift; # 既に内部利用辞書ファイルがある場合には、それを削除して改めて構築するか否か
    $namespace     = shift; # 辞書のネームスペースを指定

    if(not defined($namespace)){
        die encode_utf8("初期化エラー: namespaceを指定してください。\n");
    }

    #立ち上げ時に必要なファイルリスト
    $enzymeDict = "enzyme/enzyme_accepted_names.txt";
    $locustag_prefix_name = "locus_tag_prefix.txt";
    $embl_locustag_name = "uniprot_evaluation/Embl2LocusTag.txt";
    $gene_symbol_name = "UniProtPrefGeneSymbols.txt";
    $family_name = "pfam-ac.txt";
    $white_list = 'ValidationWhiteDictionary.txt';
    $black_list = 'ValidationBlackDictionary.txt';

    @sp_words = qw/putative probable possible/;
    @avoid_cs_terms = (
	"subunit",
	"domain protein",
	"family protein",
	"-like protein",
	"fragment",
	);
    for ( @avoid_cs_terms ){
	s/[^\w\s]//g;
	do {$negative_min_words{$_} = 1} for split " ";
    }

    # 未定議の場合の初期値
    $cos_threshold //= 0.6;
    $e_threashold //= 30;
    $cs_max //= 5;
    $n_gram //= 3;
    $ignore_chars = qr{[-/,:+()]};

    $cosine_object = Bag::Similarity::Cosine->new;
    $esearch = Search::Elasticsearch->new();
    #$esearch = Search::Elasticsearch->new(serializer => 'JSON::XS');
    #$esearch = Search::Elasticsearch->new(cxn_pool => 'Sniff');

    readDict();
}

=head
    類似度計算用辞書およびマッチ（完全一致）用辞書の構築
    類似度計算は simstring
    類似度計算用辞書の見出し語は全て空白文字を除去し、小文字化したもの
    書換前後の語群それぞれを独立した辞書にしている
    完全一致はハッシュ
    ハッシュは書換用辞書とキュレーテッド
    更に書換用辞書についてはconvtableとcorrect_definition
    convtableのキーは書換前の語に対して特殊文字を除去し、小文字化したもの
    convtableの値は書換後の語
    correct_definitionのキーは書換後の語に対して特殊文字を除去し、小文字化したもの
    correct_definitionの値は書換後の語
=cut

sub readDict {

    # our (
    # 	%correct_definitions, # マッチ用内部辞書には全エントリが小文字化されて入るが、同じく小文字化したクエリが完全一致した場合には辞書に既にあるとして処理する。
    # 	%convtable,           # 書換辞書の書換前後の対応表。小文字化したクエリが、同じく小文字化した書換え前の語に一致した場合は対応する書換後の語を一致させて出力する。
    # 	%wospconvtableD, %wospconvtableE, # 全空白文字除去前後の対応表。書換え前と後用それぞれ。
    # 	);

    # 類似度計算用辞書構築の準備
    #my $dictdir = 'dictionary/cdb_nite_ALL';
    (my $dname = basename $niteAll) =~ s/\..*$//;
    my $dictdir = 'dictionary/'.$dname;
    $md5dname = md5_hex($dname);

    # my $niteall_after_db;
    # my $niteall_before_db;

    # $nitealldb_after_name = $sysroot.'/'.$dictdir.'/after';   # After
    # $nitealldb_before_name = $sysroot.'/'.$dictdir.'/before'; # Before

    print "### Text::Annotation\n";
    print "dictdir: $dictdir\n";
    print "md5name: $md5dname\n";

    # if( $useCurrentDict ){
    #     print "Unprepare: Dictionary is reused. [TODO: checking whether or not the dictionary is present.]\n";
    # }else{
    #     print "Prepare: Dictionary.\n";
    # 	if (!-d  $sysroot.'/'.$dictdir){
    # 	    mkpath($sysroot.'/'.$dictdir);
    # 	}
    # 	for my $f ( <${sysroot}/${dictdir}/after*> ){
    # 	    unlink $f;
    # 	}
    # 	for my $f ( <${sysroot}/${dictdir}/before*> ){
    # 	    unlink $f;
    # 	}

    # 	$niteall_after_db = simstring::writer->new($nitealldb_after_name, $n_gram);
    # 	$niteall_before_db = simstring::writer->new($nitealldb_before_name, $n_gram);
    # }

    # print "Prepare: Curated Dictionary.\n";
    # # キュレーテッド辞書の構築
    # if($curatedDict){
    # 	#open(my $curated_dict, $sysroot.'/'.$curatedDict);
    # 	open(my $curated_dict, $curatedDict);
    # 	while(<$curated_dict>){
    # 	    chomp;
    # 	    my (undef, undef, undef, undef, $name, undef, $curated, $note) = split /\t/;
    # 	    $name //= "";
    # 	    trim( $name );
    # 	    trim( $curated );
    # 	    $name =~ s/^"\s*//;
    # 	    $name =~ s/\s*"$//;
    # 	    $curated =~ s/^"\s*//;
    # 	    $curated =~ s/\s*"$//;

    # 	    if($curated){
    # 		$curatedHash{lc($name)} = $curated;
    # 	    }
    # 	}
    # 	close($curated_dict);
    # }

    # 酵素辞書の構築
    print "Prepare: Enzyme Dictionary.\n";
    open(my $enzyme_dict, $sysroot.'/'.$enzymeDict);
    while(<$enzyme_dict>){
	chomp;
	trim( $_ );
	$enzymeHash{lc($_)} = $_;
    }
    close($enzyme_dict);

    # Locus tagのprefixリストを取得し、辞書を構築
    print "Prepare: Locus Prefix Dictionary.\n";
    my @prefix_array;
    open(my $locustag_prefix, $sysroot.'/'.$locustag_prefix_name);
    while(<$locustag_prefix>){
	chomp;
	s/^"//;
	s/"$//;
	trim( $_ );
	push @prefix_array, lc($_."_");
    }
    close($locustag_prefix);
    $locustag_prefix_matcher = Text::Match::FastAlternatives->new( @prefix_array );

    # EMBLから取得したLocus tagリストの辞書構築
    print "Prepare: Locus Tag Dictionary.\n";
    my @locustag_array;
    open(my $embl_locustag, $sysroot.'/'.$embl_locustag_name);
    while(<$embl_locustag>){
	chomp;
	my ($eid, $lct) = split /\t/;
	next if $eid eq '"emblid"';
	$lct =~ s/^"//;
	$lct =~ s/"$//;
	trim( $_ );
	push @locustag_array, lc($_);
    }
    close($embl_locustag);
    $embl_locustag_matcher = Text::Match::FastAlternatives->new( @locustag_array ); # 初期化中、最も時間のかかる部分

    # UniProtのReviewed=Trueなエントリについて、それをコードする遺伝子名のprefLabelにあるシンボル
    print "Prepare: Gene Symbol Dictionary.\n";
    my @gene_symbol_array;
    open(my $gene_symbol, $sysroot.'/'.$gene_symbol_name);
    while(<$gene_symbol>){
	chomp;
	trim( $_ );
	push @gene_symbol_array, lc($_);
    }
    close($gene_symbol);
    $gene_symbol_matcher = Text::Match::FastAlternatives->new( @gene_symbol_array );

    # Pfamデータベースにあるファミリー名
    print "Prepare: Pfam Dictionary.\n";
    my @pfam_family_array;
    open(my $pfam_family, $sysroot.'/'.$family_name);
    while(<$pfam_family>){
	chomp;
	trim( $_ );
	push @pfam_family_array, lc($_);
    }
    close($pfam_family);
    $family_name_matcher = Text::Match::FastAlternatives->new( @pfam_family_array );

    # White Listのロード
    print "Prepare: White List.\n";
    my @white_list_array;
    open(my $white_list_fh, $sysroot.'/'.$white_list);
    while(<$white_list_fh>){
	chomp;
	trim( $_ );
	push @white_list_array, lc(' '.$_.' ');
    }
    close($white_list_fh);
    $white_list_matcher = Text::Match::FastAlternatives->new( @white_list_array );

    # Black Listのロード
    print "Prepare: Black List.\n";
    my @black_list_array;
    open(my $black_list_fh, $sysroot.'/'.$black_list);
    while(<$black_list_fh>){
	chomp;
	trim( $_ );
	push @black_list_array, lc(' '.$_.' ');
    }
    close($black_list_fh);
    $black_list_matcher = Text::Match::FastAlternatives->new( @black_list_array );

    print "Prepare: Done.\n";

    # # 辞書を構築しない場合は以下の分岐内でreturnする
    # if( $useCurrentDict ){
    # 	print "Reading histogram.\n";
    # 	my $decoder = Sereal::Decoder->new();
    # 	$histogram = sereal_decode_with_object($decoder, read_file($sysroot.'/'.$dictdir.'/histogram'));
    # 	print "Done.\n";
    # 	return;
    # }

#
# useCurrentDictがFalseのときのみ以下のコードが実行される
#

# 類似度計算用および変換用辞書の構築
=head
    $name  : 変換後デフィニション
    $b4name: 変換前デフィニション

    基本的な処理は、入力された文字列に対して変換後デフィニションとマッチするかを調べる。
    マッチすれば当該文字列は望ましいものなので、そのまま出力して終了。
    続いて、変換前デフィニションにマッチするか調べる。
    マッチすれば当該文字列は、対応する変換後デフィニションに書き換えることが望ましいので、当該変換後デフィニションを出力して終了。
    続いて、類似マッチアルゴリズムを用いて同様の処理を行う。
=cut
    # my $total = 0;
    # my $nite_all;
    # if($niteAll =~ /\.gz$/){
    # 	#open($nite_all, "<:gzip", $sysroot.'/'.$niteAll);
    # 	open($nite_all, "<:gzip", $niteAll);
    # }else{
    # 	#open($nite_all, $sysroot.'/'.$niteAll);
    # 	open($nite_all, $niteAll);
    # }
    # while(<$nite_all>){
    # 	chomp;
    # 	my (undef, $sno, $chk, undef, $name, $b4name, undef) = split /\t/;
    # 	next if $chk eq 'RNA' or $chk eq 'OK';
    # 	# next if $chk eq 'RNA' or $chk eq 'del' or $chk eq 'OK';

    # 	$name //= "";   # $chk が "del" のときは $name が空。
    # 	trim( $name );
    # 	trim( $b4name );
    # 	$name =~ s/^"\s*//;
    # 	$name =~ s/\s*"$//;
    # 	$b4name =~ s/^"\s*//;
    # 	$b4name =~ s/\s*"$//;

    # 	$name_provenance{$name} = "dictionary";
    # 	if($curatedHash{lc($name)}){
    # 	    my $_name = lc($name);
    # 	    $name = $curatedHash{$_name};
    # 	    $name_provenance{$name} = "curated (after)";
    # 	    # print "#Curated (after): ", $_name, "->", $name, "\n";
    # 	}else{
    # 	    for ( @sp_words ){
    # 		$name =~ s/^$_\s+//i;
    # 	    }
    # 	}

    # 	my $lcb4name = lc($b4name);
    # 	$lcb4name =~ s{$ignore_chars}{ }g;
    # 	$lcb4name = trim($lcb4name);
    # 	$lcb4name =~ s/  +/ /g;
    # 	for ( @sp_words ){
    # 	    if(index($lcb4name, $_) == 0){
    # 		$lcb4name =~ s/^$_\s+//;
    # 	    }
    # 	}

    # 	if($chk eq 'del'){
    # 	    $convtable{$lcb4name}{'__DEL__'}++;
    # 	}else{
    # 	    $convtable{$lcb4name}{$name}++;

    # 	    # $niteall_before_db->insert($lcb4name);
    # 	    (my $wosplcb4name = $lcb4name) =~ s/ //g;   #### 全ての空白を取り除く（wosplc=WithOut SPace Lower Case）
    # 	    $niteall_before_db->insert($wosplcb4name);
    # 	    $wospconvtableE{$wosplcb4name}{$lcb4name}++;

    # 	    my $lcname = lc($name);
    # 	    $lcname =~ s{$ignore_chars}{ }g;
    # 	    $lcname = trim($lcname);
    # 	    $lcname =~ s/  +/ /g;
    # 	    next if $correct_definitions{$lcname};
    # 	    $correct_definitions{$lcname} = $name;
    # 	    for ( split " ", $lcname ){
    # 		s/\W+$//;
    # 		$histogram->{$_}++;
    # 		$total++;
    # 	    }
    # 	    #$niteall_after_db->insert($lcname);
    # 	    (my $wosplcname = $lcname) =~ s/ //g;   #### 全ての空白を取り除く
    # 	    $niteall_after_db->insert($wosplcname);
    # 	    $wospconvtableD{$wosplcname}{$lcname}++;
    # 	}
    # }
    # close($nite_all);

    # $niteall_after_db->close;
    # $niteall_before_db->close;

    # my $encoder = Sereal::Encoder->new();
    # write_file($sysroot.'/'.$dictdir.'/histogram', sereal_encode_with_object($encoder, $histogram));
    # loadEsearch();

}

# sub loadEsearch {
#     eval{ $esearch->get(index=> "dict_".$md5dname, type=> "convtable", id=> 1); };
#     if(!$@){
# 	print "Already exits: dict_$md5dname \n";
#         #$esearch->indices->put_alias(index => "dict_".$md5dname , name => $namespace);
# 	return;

# 	print "Delete Elasticsearch index: dict_$md5dname \n";
# 	$esearch->indices->delete(index=> "dict_".$md5dname) or print "No exist index dict_$md5dname\n";
#     }
#     print "Loading some dictionaries to Elasticsearch.\n";
#     for my $type (qw/convtable correct_definitions wospconvtableD wospconvtableE/) {
# 	my $id = 0;
# 	print $type,"\n";
# 	no strict "refs";
# 	while(my ($tkey, $tvalue) = each %{$type}){
# 	    $id++;
# 	    if($type eq "correct_definitions"){
# 		$esearch->index( index => "dict_".$md5dname, type => $type, id => $id, body => { name => $tvalue, normalized_name => $tkey, frequency => 0 });
# 	    }else{
# 		while(my ($name, $frequency) = each %$tvalue){
# 		    $esearch->index( index => "dict_".$md5dname, type => $type, id => $id, body => { name => $name, normalized_name => $tkey, frequency => $frequency });
# 		}
# 	    }
# 	}
#     }
#     print "Done.\n";
#     ### create alias
#     print "Create Aliase $namespace w/ $md5dname.\n";
#     # $esearch->indices->create(index=>"dict_".$md5dname , body=>{aliases=> $namespace});
#     $esearch->indices->put_alias(index => "dict_".$md5dname , name => $namespace);
# }

# sub openDicts {
#     print "Open: $nitealldb_after_name\n";
#     print "Open: $nitealldb_before_name\n";
#     $niteall_after_cs_db = simstring::reader->new($nitealldb_after_name);
#     $niteall_after_cs_db->swig_measure_set($simstring::cosine);
#     $niteall_after_cs_db->swig_threshold_set($cos_threshold);
#     $niteall_before_cs_db = simstring::reader->new($nitealldb_before_name);
#     $niteall_before_cs_db->swig_measure_set($simstring::cosine);
#     $niteall_before_cs_db->swig_threshold_set($cos_threshold);
#     print "Done.\n";
#     open($eslogfh, ">>:utf8", "eslog_".$namespace.".log");
# }

# sub closeDicts {
#     $niteall_after_cs_db->close;
#     $niteall_before_cs_db->close;
#     close($eslogfh);
# }

# sub chk_convtable_a_all {
#     my @terms = map { {"term" => {"normalized_name.keyword" => $_}} } @{$_[0]};
#     my $termkeywords = join(",", map {values(%{$_->{"term"}})} @terms);
#     print $eslogfh join("|", ('index:dict_'. $md5dname, "type:convtable", "body:query:bool:should:term=>".$termkeywords, "size:500")), "\n";
#     my $results = $esearch->search(
# 	index => 'dict_'. $md5dname,
# 	type => 'convtable',
# 	body => {
# 	    query => {
# 		bool => {
# 		    should => \@terms,
# 		}},
# 	    size => 500
# 	});
#     return $results->{"hits"}->{"hits"}; # the ref to an array
# }

# sub chk_convtable_a {
#     print $eslogfh join("|", ('index:dict_'. $md5dname, "type:convtable", "body:query:term:normalized_name.keyword:".$_[0])), "\n";
#     my $results = $esearch->search(
# 	index => 'dict_'. $md5dname,
# 	type => 'convtable',
# 	body => {
# 	    query => {
# 		term => { "normalized_name.keyword" => $_[0] }
# 	    }}
# 	);
#     return $results->{"hits"}->{"hits"}; # the ref to an array
# }

# sub mget_wospconv {
#     my @terms = map { {"term" => {"normalized_name.keyword" => $_}} } @{$_[1]};
#     my $termkeywords = join(",", map {values(%{$_->{"term"}})} @terms);
#     print $eslogfh join("|", ('index:dict_'. $md5dname, "type:wospconvtable".$_[0], "body:query:bool:should:term=>".$termkeywords, "size:0", "aggs:distinct:terms:{field:name.keyword,size:1000}")), "\n";
#     my $results = $esearch->search(
# 	index => 'dict_'.$md5dname,
# 	type => 'wospconvtable'.$_[0], # "D" or "E"
# 	body => {
# 	    query => {
# 		bool => {
# 		    should => \@terms,
# 		}},
# 	    size => 0,
# 	    aggs => {
# 		distinct => {
# 		    terms => {
# 			field => "name.keyword",
# 			size => 1000
# 		    }
# 		}}
# 	});
#     return $results->{"aggregations"}->{"distinct"}->{"buckets"}; # the ref to an array
# }

# sub get_all_wospconv {
#     my @terms = map { {"term" => {"normalized_name.keyword" => $_}} } @{$_[1]};
#     my $termkeywords = join(",", map {values(%{$_->{"term"}})} @terms);
#     print $eslogfh join("|", ('index:dict_'. $md5dname, "type:wospconvtable".$_[0], "body:query:bool:should:term=>".$termkeywords, "size:500")), "\n";
#     my $results = $esearch->search(
# 	index => 'dict_'.$md5dname,
# 	type => 'wospconvtable'.$_[0], # "D" or "E"
# 	body => {
# 	    query => {
# 		bool => {
# 		    should => \@terms,
# 		}},
# 	    size => 500
# 	});
#     return $results->{"hits"}->{"hits"}; # the ref to an array
# }

# sub chk_convtable_b {
#     print $eslogfh join("|", ('index:dict_'. $md5dname, "type:convtable", "body:query:bool:must:{term:normalized_name.keyword:$_[0],term:name.keyword:__DEL__}")), "\n";
#     my $results = $esearch->search(
# 	index => 'dict_'. $md5dname,
# 	type => 'convtable',
# 	body => {
# 	    query => {
# 		bool => {
# 		    must => [
# 			{ term =>
# 			  {
# 			      "normalized_name.keyword" => $_[0],
# 			  }},
# 			{ term =>
# 			  {
# 			      "name.keyword" => '__DEL__',
# 			  }}],
# 		}}});
#     return $results->{"hits"}->{"total"}; # # of hits
# }

# sub get_correct_definitions {
#     print $eslogfh join("|", ('index:dict_'. $md5dname, "type:correct_definitions", "body:query:term:normalized_name.keyword:$_[0]", "size:1")), "\n";
#     my $results = $esearch->search(
# 	index => 'dict_'.$md5dname,
# 	type => 'correct_definitions',
# 	body => {
# 	    query => {
# 		term => { "normalized_name.keyword" => $_[0] }
# 	    },
# 	    size => 1
# 	});
#     my $ptr = $results->{"hits"}->{"hits"};
#     if(@$ptr){
# 	return $ptr->[0]->{"_source"}->{"name"};
#     }else{
# 	return "";
#     }
# }

sub retrieve {
=head
    オリジナルのクエリは $oq に格納される
    マッチ用に小文字化し、記号類を全て空白にする
    連続した空白は空白一文字にする
=cut
    shift;
    ($minfreq, $minword, $ifhit, $cosdist) = undef;
    my $query = my $oq = shift;
    # $query ||= 'hypothetical protein';

    $lcquery =~ s{$ignore_chars}{ }g;
    $lcquery =~ s/^"\s*//;
    $lcquery =~ s/\s*"\s*$//;
    $lcquery =~ s/\s+\[\w+\]$//;
    $lcquery =~ s/\s*"$//;
    $lcquery =~ s/  +/ /g;
    $lcquery = trim($lcquery);

    my $prfx = '';
    my ($match, $result, $info) = ('') x 3;
    my @results;
    for ( @sp_words ){
        if(index($lcquery, $_) == 0){
            $lcquery =~ s/^$_\s+//;
	    $prfx = $_. ' ';
	    last;
        }
    }

=head
    if( (my $cd = get_correct_definitions( $lcquery )) ne "" ){ # 続いてafterに完全マッチするか
        $match ='ex';
	$result = $oq;
	$info = 'in_dictionary'. ($prfx?" (prefix=${prfx})":"");
	$results[0] = $result;
    }elsif( my @chkconvtbla_set = @{ chk_convtable_a( $lcquery ) } ){ # そしてbeforeに完全マッチするか
	if( chk_convtable_b( $lcquery ) ){
	    my @others = grep {$_->{"_source"}->{"name"} ne '__DEL__'} @chkconvtbla_set;
	    $match = 'del';
	    $result = $lcquery;
	    $info = 'Human check preferable (other entries with the same "before" entry: '.join(" @@ ", @others).')';
	}else{
	    $match = 'ex';
	    $result = join(" @@ ", map {$prfx. ($_->{"_source"}->{"name"}) } @chkconvtbla_set );
	    $info = 'convert_from dictionary'. ($prfx?" (prefix=${prfx})":"");
	    $results[0] = $result;
	}
    }else{ # そして類似マッチへ
	# Afterの場合は、%wospconvtableDの、simstringで得られた$wosplcnameに対応する$lcnameをすべて取得する(mget_wospconv)のに対し、
	# Beforeの場合は、%wospconvtableEの、同じくsimstringで得られた$wosplcb4nameに対する$lcb4nameのうち、クエリを構成する単語が含まれるものだけに絞っている。
	my $avoidcsFlag = 0;
	for ( @avoid_cs_terms ){
	    $avoidcsFlag = ($lcquery =~ m,\b$_$,);
	    last if $avoidcsFlag;
	}
	#全ての空白を取り除く処理をした場合への対応
	(my $qwosp = $lcquery) =~ s/ //g;
	my $retr = [ "" ];
	if(defined($qwosp)){
	    $retr = $niteall_after_cs_db->retrieve($qwosp);
	}
	#####
	my %qtms = map {$_ => 1} grep {s/\W+$//;$histogram->{$_}} (split " ", $lcquery);
	if($retr->[0]){
	    ($minfreq, $minword, $ifhit, $cosdist) = getScore($retr, \%qtms, 1, $qwosp);
	    #my %cache;
	    #全ての空白を取り除く処理をした場合には検索結果の文字列を復元する必要があるため、下記部分をコメントアウトしている。
	    #my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /} grep {$cache{$_}++; $cache{$_} == 1} @$retr;
	    my @out = sort by_priority map { $_->{"key"} } @{ mget_wospconv("D", $retr) };
	    #その代わり以下のコードが必要。
	    #my @out = sort by_priority grep {$cache{$_}++; $cache{$_} == 1} map { keys %{$wospconvtableD{$_}} } @$retr;
	    #####
	    my $le = (@out > $cs_max)?($cs_max-1):$#out;
	    if($avoidcsFlag && $minfreq->{$out[0]} == -1 && $negative_min_words{$minword->{$out[0]}}){
		$match ='no_hit';
		$result = $oq;
		$info = 'cs_avoidance';
	    }else{
		$match = 'cs';
		my @result_set = map { get_correct_definitions( $_ ) } @out[0..$le];
		$result = $prfx.( $result_set[0] );
		$info   = join(" @@ ", (map {$prfx.( $result_set[$_] ).' ['.$minfreq->{$out[$_]}.':'.$minword->{$out[$_]}.']'} (0..$le) ));
		@results = map { $prfx.$_ } @result_set;
	    }
	}else{
	    #全ての空白を取り除く処理をした場合への対応
	    #my $retr_e = $niteall_before_cs_db->retrieve($lcquery);
	    my $retr_e = [ "" ];
	    if(defined($qwosp)){
		$retr_e = $niteall_before_cs_db->retrieve($qwosp);
	    }
	    #####
	    if($retr_e->[0]){
		($minfreq, $minword, $ifhit, $cosdist) = getScore($retr_e, \%qtms, 0, $qwosp);
		my @hits = keys %$ifhit;
		my %cache;
		my @out = sort by_priority grep {$cache{$_}++; $cache{$_} == 1 && $minfreq->{$_} < $e_threashold} @hits;
		my $le = (@out > $cs_max)?($cs_max-1):$#out;
		if(defined $out[0] && $avoidcsFlag && $minfreq->{$out[0]} == -1 && $negative_min_words{$minword->{$out[0]}}){
		    $match ='no_hit';
		    $result = $oq;
		    $info = 'bcs_avoidance';
		}else{
		    $match = 'bcs';
		    $result = $oq;
		    $info = "Cosine_Sim_To:".join(" % ", @$retr_e);
		    if( defined $out[0] ){
			my %conv_result;
			for ( @{ chk_convtable_a_all( [ @out[0..$le] ] ) } ){
			    push @{ $conv_result{$_->{"_source"}->{"normalized_name"}} }, $prfx. $_->{"_source"}->{"name"};
			}
			$result = join(" @@ ", @{ $conv_result{$out[0]} } );
			$info   = join(" % ", (map {join(" @@ ", map { $_ } @{ $conv_result{$_} } ).' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
		    }
		}
	    } else {
		$match  = 'no_hit';
		$result = $oq;
	    }
	}
    }
=cut
    $result = b2a($result);

    my %annotations;
    getAnnotations($oq, \$info, \%annotations);
    return({'query'=> $oq, 'result' => $result, 'match' => $match, 'info' => $info, 'result_array' => \@results, 'annotation' => \%annotations});
}

sub getAnnotations{
    my $oq = shift;
    my $info = shift;
    my $annotations = shift;

    if($enzymeHash{lc($oq)}){
	$$info .= " [Enzyme name]";
	$annotations->{"Enzyme"} = [ $oq ];
    }
    for (split " ", lc($oq)){
	if($embl_locustag_matcher->exact_match($_)){
	    $$info .= " [Locus tag]";
	    push @{ $annotations->{"Locus tag"} }, $_;
	}elsif($locustag_prefix_matcher->match_at($_, 0)){
	    $$info .= " [Locus prefix]";
	    push @{ $annotations->{"Locus prefix"} }, $_;
	}
    }
    if($gene_symbol_matcher->exact_match($oq)){
	$$info .= " [Gene symbol]";
	$annotations->{"Gene symbol"} = [ $oq ];
    }
    if($family_name_matcher->exact_match($oq)){
	$$info .= " [Family name]";
	$annotations->{"Family name"} = [ $oq ];
    }
    if($white_list_matcher->match(' '.$oq.' ')){
	$$info .= " [White list]";
	my @unmatched;
	(my $fm = $oq) =~ y|-()[]/,| |;
	$fm =~ s/\'/ /g;
	$fm =~ s/  +/ /g;
	trim( $fm );
	for ( split / /, $fm ){
	    if( $white_list_matcher->exact_match(lc $_) ){
	    } else {
		push @unmatched, $_;
	    }
	}
	$annotations->{"White list unmatched"} = \@unmatched;
    }else{
	$$info .= " [Not in the white list]";
    }
    if($black_list_matcher->match(' '.$oq.' ')){
	$$info .= " [Black list]";
	$annotations->{"Black list"} = [ $oq ];
    }
}

sub by_priority {
    #my $minfreq = shift;
    #my $cosdist = shift;
      
    #  $minfreq->{$a} <=> $minfreq->{$b} || $cosdist->{$b} <=> $cosdist->{$a} || $a =~ y/ / / <=> $b =~ y/ / /
    ## $cosdist->{$b} <=> $cosdist->{$a} || $minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /
        guideline_penalty($a) <=> guideline_penalty($b)
         or 
        $minfreq->{$a} <=> $minfreq->{$b}
         or 
        $cosdist->{$b} <=> $cosdist->{$a}
         or 
        $a =~ y/ / / <=> $b =~ y/ / /
}

sub guideline_penalty {
 my $result = shift; 
 my $idx = 0;

#1. (酵素名辞書に含まれている場合)
 $idx-- if $enzymeHash{lc($result)};

#2. 記述や句ではなく簡潔な名前を用いる。
 $idx++ if $result =~/ (of|or|and) /;
#5. タンパク質名が不明な場合は、 産物名として、"unknown” または "hypothetical protein”を用いる。今回の再アノテーションでは、"hypothetical protein”の使用を推奨する。
 $idx++ if $result =~/(unknown protein|uncharacterized protein)/;
#7. タンパク質名に分子量の使用は避ける。例えば、"unicornase 52 kDa subunit”は避け、"unicornase subunit A” 等と表記する。
 $idx++ if $result =~/\d+\s*kDa/;
#8. 名前に“homolog”を使わない。
 $idx++ if $result =~/homolog/;
#9. 可能なかぎり、コンマを用いない。
 $idx++ if $result =~/\,/;
#12. 可能な限りローマ数字は避け、アラビア数字を用いる。
 $idx++ if $result =~/[I-X]/;
#16. ギリシャ文字は、小文字でスペルアウトする（例：alpha）。ただし、ステロイドや脂肪酸代謝での「デルタ」は例外として語頭を大文字にする（Delta）。さらに、番号が続いている場合、ダッシュ" -“の後に続ける（例：unicornase alpha-1）。
 $idx++ if $result =~/(\p{Greek})/;
#17. アクセント、ウムラウトなどの発音区別記号を使用しない。多くのコンピュータシステムは、ASCII文字しか判別できない。 
 $idx++ if $result =~/(\p{Mn})/;

#3. 理想的には命名する遺伝子名（タンパク質名）はユニークであり、すべてのオルソログに同じ名前がついているとよい。
#4. タンパク質名に、タンパク質の特定の特徴を入れない。 例えば、タンパク質の機能、細胞内局在、ドメイン構造、分子量やその起源の種名はノートに記述する。
#6. タンパク質名は、対応する遺伝子と同じ表記を用いる。ただし，語頭を大文字にする。
#10. 語頭は基本的に小文字を用いる。（例外：DNA、ATPなど）
#11. スペルはアメリカ表記を用いる。→ 実装済み（b2a関数の適用）
#13. 略記に分子量を組み込まない。
#14. 多重遺伝子ファミリーに属するタンパク質では、ファミリーの各メンバーを指定する番号を使用することを推奨する。
#15. 相同性または共通の機能に基づくファミリーに分類されるタンパク質に名前を付ける場合、"-"に後にアラビア数字を入れて標記する。（例："desmoglein-1", "desmoglein-2"など）
#18. 複数形を使用しない。"ankyrin repeats-containing protein 8" は間違い。
#19 機能未知タンパク質のうち既知のドメインまたはモチーフを含む場合、ドメイン名を付して名前を付けてもよい。例えば "PAS domain-containing protein 5" など。
 return $idx;
}

# sub getScore {
#     my $retr = shift;
#     my $qtms = shift;
#     my $minf = shift;
#     my $query = shift;
#     my (%minfreq, %minword, %ifhit, %cosdistance);
#     # 対象タンパク質のスコアは、当該タンパク質を構成する単語それぞれにつき、検索対象辞書中での当該単語の出現頻度のうち最小値を割り当てる
#     # 最小値を持つ語は $minword{$_} に代入する
#     # また、検索タンパク質名を構成する単語が、検索対象辞書からヒットした各タンパク質名に含まれている場合は $ifhit{$_} にフラグが立つ

#     #全ての空白を取り除く処理をした場合への対応
#     my $wospct = ($minf)? "D" : "E";
#     #my $wospct = ($minf)? \%wospconvtableD : \%wospconvtableE;
#     #####
#     for my $hit ( @{ get_all_wospconv($wospct, $retr) } ) { # <--- 全ての空白を取り除く処理をした場合への対応
# 	my $wosp = $hit->{"_source"}->{"normalized_name"};
# 	$_ = $hit->{"_source"}->{"name"};
# 	$cosdistance{$_} = $cosine_object->similarity($query, $wosp, $n_gram);
# 	my $score = 100000;
# 	my $word = '';
# 	my $hitflg = 0;
# 	for (split){
# 	    my $h = $histogram->{$_} // 0;
# 	    if($qtms->{$_}){
# 		$hitflg++;
# 	    }else{
# 		$h += 10000;
# 	    }
# 	    if($score > $h){
# 		$score = $h;
# 		$word = $_;
# 	    }
# 	}
# 	$minfreq{$_} = $score;
# 	$minword{$_} = $word;
# 	$ifhit{$_}++ if $hitflg;
#     }
#     # 検索タンパク質名を構成する単語が、ヒットした各タンパク質名に複数含まれる場合には、その中で検索対象辞書中での出現頻度スコアが最小であるものを採用する
#     # そして最小の語のスコアは-1とする。
#     my $leastwrd = '';
#     my $leastscr = 100000;
#     for (keys %ifhit){
# 	if($minfreq{$_} < $leastscr){
# 	    $leastwrd = $_;
# 	    $leastscr = $minfreq{$_};
# 	}
#     }
#     if($minf && $leastwrd){
# 	for (keys %minword){
# 	    $minfreq{$_} = -1 if $minword{$_} eq $minword{$leastwrd};
# 	}
#     }
#     return (\%minfreq, \%minword, \%ifhit, \%cosdistance);
# }

1;
__END__

=head1 NAME

Protein Definition Normalizer

=head1 SYNOPSIS

normProt.pl -t0.7

=head1 ABSTRACT

配列相同性に基いて複数のプログラムにより自動的に命名されたタンパク質名の表記を、既に人手で正規化されている表記を利用して正規形に変換する。

=head1 COPYRIGHT AND LICENSE

Copyright by Yasunori Yamamoto / Database Center for Life Science
このプログラムはフリーであり、また、目的を問わず自由に再配布および修正可能です。

=cut
