package Text::TogoAnnotatorES;

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
# * 2019.3.1
# 新生Elasticsearch対応のために大幅な変更を施す。

use warnings;
use strict;
use utf8;
use Fatal qw/open/;
use open qw/:utf8/;
use File::Basename;
use String::Trim;
use Lingua::EN::ABC qw/b2a/;
use Text::Match::FastAlternatives;
use Algorithm::AhoCorasick::XS;
use Search::Elasticsearch;
use Digest::MD5 qw/md5_hex/;
use Encode;
use WWW::Curl::Easy;
use JSON::XS;
use Data::Dumper;

my ($sysroot, $niteAll, $curatedDict, $enzymeDict, $locustag_prefix_name, $embl_locustag_name, $gene_symbol_name, $family_name, $esearch);
my ($white_list, $black_list);
my ($cos_threshold, $e_threashold, $cs_max, $n_gram, $ignore_chars);
my ($locustag_prefix_matcher, $embl_locustag_matcher, $gene_symbol_matcher, $family_name_matcher);
# my ($useCurrentDict, $md5dname);
# my ($namespace);

my (
    @sp_words,      # マッチ対象から外すが、マッチ処理後は元に戻して結果に表示させる語群。
    @avoid_cs_terms # コサイン距離を用いた類似マッチの対象にはしない文字列群。種々の辞書に完全一致しない場合はno_hitとする。
    );
my (
    %negative_min_words,  # コサイン距離を用いた類似マッチではクエリと辞書中のエントリで文字列としては類似していても、両者の間に共通に出現する語が無い場合がある。
    # その場合、共通に出現する語がある辞書中エントリを優先させる処理をしているが、本処理が逆効果となってしまう語がここに含まれる。
    # %name_provenance,     # 変換後デフィニションの由来。
    # %curatedHash,         # curated辞書のエントリ（キーは小文字化する）
    %enzymeHash,           # 酵素辞書のエントリ（小文字化する）
    %black2white,            # ブラックリストで書き換え対象が記載されている場合の書き換え用ハッシュ（のハッシュ）
    %white_matcher,
    %black_matcher
    );
my ($minfreq, $minword, $ifhit, $cosdist);

sub init {
    my $_this = shift;
    $cos_threshold = shift; # 使わず。cosine距離で類似度を測る際に用いる閾値。この値以上類似している場合は変換対象の候補とする。
    $e_threashold  = shift; # 使わず。E列での表現から候補を探す場合、辞書中での最大出現頻度がここで指定する数未満の場合のもののみを対象とする。
    $cs_max        = shift; # 使わず。複数表示する候補が在る場合の最大表示数。
    $n_gram        = shift; # 使わず。N-gram
    $sysroot       = shift; # 辞書や作業用ファイルを生成するディレクトリ。
    # $niteAll       = shift; # 使わず。辞書名
    # $curatedDict   = shift; # 使わず。curated辞書名（形式は同一）
    # $useCurrentDict= shift; # 使わず。既に内部利用辞書ファイルがある場合には、それを削除して改めて構築するか否か
    # $namespace     = shift; # 使わず。辞書のネームスペースを指定

    #if(not defined($namespace)){
    #    die encode_utf8("初期化エラー: namespaceを指定してください。\n");
    #}

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
    # $cos_threshold //= 0.6;
    # $e_threashold //= 30;
    # $cs_max //= 5;
    # $n_gram //= 3;
    $ignore_chars = qr{[-/,:+()]};
    #$esearch = Search::Elasticsearch->new();

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

    # 類似度計算用辞書構築の準備
    # my $dictdir = 'dictionary/cdb_nite_ALL';
    # (my $dname = basename $niteAll) =~ s/\..*$//;
    # my $dictdir = 'dictionary/'.$dname;
    # $md5dname = md5_hex($dname);

    print "### Text::AnnotationES\n";
    # print "dictdir: $dictdir\n";
    # print "md5name: $md5dname\n";

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
    $white_matcher{"Lee"} = Text::Match::FastAlternatives->new( @white_list_array );

    # Black Listのロード
    print "Prepare: Black List.\n";
    my @black_list_array;
    open(my $black_list_fh, $sysroot.'/'.$black_list);
    while(<$black_list_fh>){
	chomp;
	trim( $_ );
	my ($b, $w) = split /\t/;
	if (defined($w)){
	    $black2white{"Lee"}{$b} = $w;
	}
	
	push @black_list_array, lc(' '.$b.' ');
    }
    close($black_list_fh);
    # $black_matcher{"Lee"} = Text::Match::FastAlternatives->new( @black_list_array );
    $black_matcher{"Lee"}= Algorithm::AhoCorasick::XS->new( \@black_list_array );


    print "Prepare: Done.\n";
}


sub makeQuery4Msearch {
    my $d =<<"MSEARCH";
    {
	"query": {
	    "bool": {
		"should": [
		    {
			"bool": {
			    "must": [
				{"term": {"query_type": "term_before"}},
				{"match": {"normalized_name.term": {"query": $_[0]}}}
				]
			}
		    },
		    {
			"bool": {
			    "must": [
				{"term": {"query_type": "term_after"}},
				{"match": {"normalized_name.term": {"query": $_[0]}}}
				]
			}
		    },
		    {
			"bool": {
			    "must": [
				{"term": {"query_type": "mlt_before"}},
				{
				    "more_like_this": {
					"fields": ["normalized_name.mlt"],
					"like": $_[0],
					"max_query_terms": str(self.mlt_params['max_query_terms']),
					"minimum_should_match": self.mlt_params['minimum_should_match'],
					"min_term_freq": str(self.mlt_params['min_term_freq']),
					"min_word_length": str(self.mlt_params['min_word_length']),
					"max_word_length": str(self.mlt_params['max_word_length'])
				    }
				}
				]
			}
		    },
		    {
			"bool": {
			    "must": [
				{"term": {"query_type": "mlt_after"}},
				{
				    "more_like_this": {
					"fields": ["normalized_name.mlt"],
					"like": $_[0],
					"max_query_terms": str(self.mlt_params['max_query_terms']),
					"minimum_should_match": self.mlt_params['minimum_should_match'] ,
					"min_term_freq": str(self.mlt_params['min_term_freq']),
					"min_word_length": str(self.mlt_params['min_word_length']),
					"max_word_length": str(self.mlt_params['max_word_length'])
				    }
				}
				]
			}
		    }
		    ]
	    }
	},
	"size": 0,
	"aggregations": {
	    "tags": {
		"terms": {
		    "field": "query_type",
		    "size": 4
		},
			"aggs": {
			    "top_tag_hits": {
				"top_hits": {
				    "size": 15
				}
			    }
		    }
	    }
	}
    }
MSEARCH
    return $d;
}

sub retrieveMulti { # $oq にクエリのリストへのポインタが入る
    shift;
    ($minfreq, $minword, $ifhit, $cosdist) = undef;

    my $query = my $oq = shift;
    my $md5dname = md5_hex(shift);
    my $es_opts_default = {
	'MAX_QUERY_TERMS'=> 100,
	'MINIMUM_SHOULD_MATCH' => '30',
	'MIN_TERM_FREQ' => 0,
	'MIN_WORD_LENGTH'=> 0,
	'MAX_WORD_LENGTH'=> 0,
	'HITS'=> 15};
    my $es_opts = shift || $es_opts_default;
    my @prfx_list;
    my @q4msearch;
    my $INDEX_NAME = "tm_".$md5dname;

    for ( @$query ){
	$_ = lc($_);
	s{$ignore_chars}{ }g;
	s/^"\s*//;
	s/\s*"\s*$//;
	s/\s+\[\w+\]$//;
	s/\s*"$//;
	s/  +/ /g;
	trim( $_ );

	my $exist_prfx = 0;
	for my $sp ( @sp_words ){
	    if(index($_, $sp) == 0){
		s/^${sp}\s+//;
		push @prfx_list, $sp. ' ';
		$exist_prfx++;
		last;
	    }
	}
	if ($exist_prfx == 0){
	    push @prfx_list, "";
	}
	push @q4msearch, encode_json {"index" => ${INDEX_NAME}};
	push @q4msearch, makeQuery4Msearch( $_ );
    }

    my $curl = WWW::Curl::Easy->new();
    my $response_body;
    print Dumper "http://172.18.8.190:19200/_msearch";
    $curl->setopt(CURLOPT_URL, "http://172.18.8.190:19200/_msearch");
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_HTTPHEADER, [
		      "Content-Type: application/json",
		  ]);
    my $MAX_QUERY_TERMS = $es_opts->{'MAX_QUERY_TERMS'} || $es_opts_default->{'MAX_QUERY_TERMS'} ; #|| 100;
    my $MINIMUM_SHOULD_MATCH = $es_opts->{'MINIMUM_SHOULD_MATCH'} || $es_opts_default->{'MINIMUM_SHOULD_MATCH'} ; #"30%";
    my $MIN_TERM_FREQ =  $es_opts->{'MIN_TERM_FREQ'} || $es_opts_default->{'MIN_TERM_FREQ'} ;      # 0;
    my $MIN_WORD_LENGTH = $es_opts->{'MIN_WORD_LENGTH'} || $es_opts_default->{'MIN_WORD_LENGTH'} ; # 0;
    my $MAX_WORD_LENGTH = $es_opts->{'MAX_WORD_LENGTH'} || $es_opts_default->{'MAX_WORD_LENGTH'} ; # 0;
    my $HITS = $es_opts->{'HITS'} || $es_opts_default->{'HITS'} ; # 15;

    my @entire_results;
    my ($match, $result, $info) = ('') x 3;
    my @results;
    my %matchtype_map = (
	"term_after", "ex",
	"term_before", "ex",
	"mlt_after", "cs",
	"mlt_before", "bcs",
    );
    my %info_map = (
	"term_after", "in_dictionary",
	"term_before", "convert_from dictionary",
	"mlt_after", "",
	"mlt_before", "",
    );

    $curl->setopt(CURLOPT_POSTFIELDS, encode_json @q4msearch);
    open (my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_WRITEDATA, $fileb);
    my $retcode = $curl->perform;

    if ($retcode == 0) {
	my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
	my $response_json = decode_json $response_body;
	print Dumper $response_json, "\n";
=head
	my $array_ptr = $response_json->{"aggregations"}->{"tags"}->{"buckets"};
	my %group_by_key;
	for ( @$array_ptr ){
	    $group_by_key{$_->{"key"}}->{"doc_count"} = $_->{"doc_count"};
	    $group_by_key{$_->{"key"}}->{"top_tag_hits"} = $_->{"top_tag_hits"};
	}
	my $avoidcsFlag = 0;
	for ( @avoid_cs_terms ){
	    $avoidcsFlag = ($lcquery =~ m,\b$_$,);
	    last if $avoidcsFlag;
	}
	for my $_key (qw/term_after term_before mlt_after mlt_before/){
	    $match = "no_hit";
	    $result = $oq;
	    if($group_by_key{$_key}){
		my @_results;
		for ( @{ $group_by_key{$_key}->{"top_tag_hits"}->{"hits"}->{"hits"} } ){
		    #push @_results, $_->{"_source"}->{"name"}, "\n";
		    push @_results, $_;
		}
		if ($_key =~ /^term_/){
		    $result = join(" @@ ", map {$prfx. ($_->{"_source"}->{"name"}) } @_results);
		    $results[0] = $result;
		} else {
		    $result = $prfx. $_results[0]->{"_source"}->{"name"};
		    @results = map { $prfx.$_->{"_source"}->{"name"} } @_results;
		}
		$match = $matchtype_map{$_key};
		$info = $info_map{$_key};
		if($_key =~ m/^mlt/){
		    if($avoidcsFlag){
			$info .= "(cs_avoidance in $_key)";
		    }
		    $info .= join(" @@ ", map {$prfx. ($_->{"_source"}->{"normalized_name"}) } @_results);
		}
		my @out;
		if($_key =~ m/^term/){
		    $info .= ($prfx?" (prefix=${prfx})":"");
		}elsif($_key =~ m/^mlt/){
		    @out = sort by_priority @_results;
		}
		last;
	    }
	}
=cut
    } else {
	warn("An error happened: ".$curl->strerror($retcode)." ($retcode)\n");
    }

=head
    $result = b2a($result);
    my %annotations;
    getAnnotations($oq, \$info, \%annotations);
    return({'query'=> $oq, 'result' => $result, 'match' => $match, 'info' => $info, 'result_array' => \@results, 'annotation' => \%annotations});
=cut
}

=head
	オリジナルのクエリは $oq に格納される
	マッチ用に小文字化し、記号類を全て空白にする
	連続した空白は空白一文字にする
=cut
sub retrieve {
    shift;
    ($minfreq, $minword, $ifhit, $cosdist) = undef;
    my $query = my $oq = shift;
    my $md5dname = md5_hex(shift);
    my $es_opts_default = {'MAX_QUERY_TERMS'=> 100, 'MINIMUM_SHOULD_MATCH' => '30','MIN_TERM_FREQ' =>0, 'MIN_WORD_LENGTH'=>0,'MAX_WORD_LENGTH'=>0, 'HITS'=>15};
    my $es_opts = shift  || $es_opts_default;
    #print Dumper $es_opts;

    # $query ||= 'hypothetical protein';
    my $lcquery = lc($query);

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

    my $curl = WWW::Curl::Easy->new();
    my $response_body;
    my $INDEX_NAME = "tm_".$md5dname;
    print Dumper "http://172.18.8.190:19200/${INDEX_NAME}/_search";
    $curl->setopt(CURLOPT_URL, "http://172.18.8.190:19200/${INDEX_NAME}/_search");
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_HTTPHEADER, [
		      "Content-Type: application/json",
		  ]);
    my $KEY_WORD = $lcquery;
    my $MAX_QUERY_TERMS = $es_opts->{'MAX_QUERY_TERMS'} || $es_opts_default->{'MAX_QUERY_TERMS'} ; #|| 100;
    my $MINIMUM_SHOULD_MATCH = $es_opts->{'MINIMUM_SHOULD_MATCH'} || $es_opts_default->{'MINIMUM_SHOULD_MATCH'} ; #"30%";
    my $MIN_TERM_FREQ =  $es_opts->{'MIN_TERM_FREQ'} || $es_opts_default->{'MIN_TERM_FREQ'} ;     # 0;
    my $MIN_WORD_LENGTH = $es_opts->{'MIN_WORD_LENGTH'} || $es_opts_default->{'MIN_WORD_LENGTH'} ; # 0;
    my $MAX_WORD_LENGTH = $es_opts->{'MAX_WORD_LENGTH'} || $es_opts_default->{'MAX_WORD_LENGTH'} ; # 0;
    my $HITS = $es_opts->{'HITS'} || $es_opts_default->{'HITS'} ; # 15;
    my $query2es =<<"QUERY";
{
  "query": {
    "bool": {
      "should": [
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "term_before"
                }
              },
              {
                "match": {
                  "normalized_name.term": {
                    "query": "${KEY_WORD}"
                  }
                }
              }
            ]
          }
        },
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "term_after"
                }
              },
              {
                "match": {
                  "normalized_name.term": {
                    "query": "${KEY_WORD}"
                  }
                }
              }
            ]
          }
        },
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "mlt_before"
                }
              },
              {
                "more_like_this": {
                  "fields": [
                    "normalized_name.mlt"
                  ],
                  "like": "${KEY_WORD}",
                  "max_query_terms": ${MAX_QUERY_TERMS},
                  "minimum_should_match": "${MINIMUM_SHOULD_MATCH}%",
                  "min_term_freq": ${MIN_TERM_FREQ},
                  "min_word_length": ${MIN_WORD_LENGTH},
                  "max_word_length":  ${MAX_WORD_LENGTH}
                }
              }
            ]
          }
        },
        {
          "bool": {
            "must": [
              {
                "term": {
                  "query_type": "mlt_after"
                }
              },
              {
                "more_like_this": {
                  "fields": [
                    "normalized_name.mlt"
                  ],
                  "like": "${KEY_WORD}",
                  "max_query_terms": ${MAX_QUERY_TERMS},
                  "minimum_should_match": "${MINIMUM_SHOULD_MATCH}",
                  "min_term_freq": ${MIN_TERM_FREQ},
                  "min_word_length": ${MIN_WORD_LENGTH},
                  "max_word_length": ${MAX_WORD_LENGTH}
                }
              }
            ]
          }
        }
      ]
    }
 },
  "size": 0,
  "aggs": {
    "tags": {
      "terms": {
        "field": "query_type",
        "size": 4
      },
      "aggs":{
        "top_tag_hits":{
          "top_hits": {
            "size": ${HITS}
          }
        }
      }
    }
  }
}
QUERY

    my %matchtype_map = (
	"term_after", "ex",
	"term_before", "ex",
	"mlt_after", "cs",
	"mlt_before", "bcs",
    );
    my %info_map = (
	"term_after", "in_dictionary",
	"term_before", "convert_from dictionary",
	"mlt_after", "",
	"mlt_before", "",
    );
    $curl->setopt(CURLOPT_POSTFIELDS, $query2es);
    open (my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    my $retcode = $curl->perform;
    if ($retcode == 0) {
	my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
	my $response_json = decode_json $response_body;
	my $array_ptr = $response_json->{"aggregations"}->{"tags"}->{"buckets"};
	my %group_by_key;
	for ( @$array_ptr ){
	    $group_by_key{$_->{"key"}}->{"doc_count"} = $_->{"doc_count"};
	    $group_by_key{$_->{"key"}}->{"top_tag_hits"} = $_->{"top_tag_hits"};
	}
	my $avoidcsFlag = 0;
	for ( @avoid_cs_terms ){
	    $avoidcsFlag = ($lcquery =~ m,\b$_$,);
	    last if $avoidcsFlag;
	}
	for my $_key (qw/term_after term_before mlt_after mlt_before/){
	    $match = "no_hit";
	    $result = $oq;
	    if($group_by_key{$_key}){
		my @_results;
		for ( @{ $group_by_key{$_key}->{"top_tag_hits"}->{"hits"}->{"hits"} } ){
		    #push @_results, $_->{"_source"}->{"name"}, "\n";
		    push @_results, $_;
		}
    if ($_key =~ /^term_/){
  		$result = join(" @@ ", map {$prfx. ($_->{"_source"}->{"name"}) } @_results);
	  	$results[0] = $result;
    } else {
  		$result = $prfx. $_results[0]->{"_source"}->{"name"};
  		@results = map { $prfx.$_->{"_source"}->{"name"} } @_results;
    }
		$match = $matchtype_map{$_key};
		$info = $info_map{$_key};
		if($_key =~ m/^mlt/){
		    if($avoidcsFlag){
			$info .= "(cs_avoidance in $_key)";
		    }
		    $info .= join(" @@ ", map {$prfx. ($_->{"_source"}->{"normalized_name"}) } @_results);
		}
		my @out;
		if($_key =~ m/^term/){
		    $info .= ($prfx?" (prefix=${prfx})":"");
		}elsif($_key =~ m/^mlt/){
		    @out = sort by_priority @_results;
		}
		last;
	    }
	}
    } else {
	warn("An error happened: ".$curl->strerror($retcode)." ($retcode)\n");
    }

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
    if($white_matcher{"Lee"}->match(' '.$oq.' ')){
	$$info .= " [White list]";
	my @unmatched;
	(my $fm = $oq) =~ y|-()[]/,| |;
	$fm =~ s/\'/ /g;
	$fm =~ s/  +/ /g;
	trim( $fm );
	for ( split / /, $fm ){
	    if( $white_matcher{"Lee"}->exact_match(lc $_) ){
	    } else {
		push @unmatched, $_;
	    }
	}
	$annotations->{"White list unmatched"} = \@unmatched;
    }else{
	$$info .= " [Not in the white list]";
    }
    my @black_matched;
    while((my $matched = $black_matcher{"Lee"}->first_match(' '.$oq.' ')) ne ""){
	$oq =~ s/${matched}/$black2white{$matched}/ if defined($black2white{$matched});
	$$info .= " [Black list]";
	push @black_matched, $matched;
    }
    $annotations->{"Black list"} = \@black_matched;
}

sub by_priority {
    #my $minfreq = shift;
    #my $cosdist = shift;
    
    #  $minfreq->{$a} <=> $minfreq->{$b} || $cosdist->{$b} <=> $cosdist->{$a} || $a =~ y/ / / <=> $b =~ y/ / /
    ## $cosdist->{$b} <=> $cosdist->{$a} || $minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /
    guideline_penalty($a) <=> guideline_penalty($b)
# FIXME: 未定義のため一時的にコメントアウト
#	or 
#        $minfreq->{$a} <=> $minfreq->{$b}
#    or 
#        $cosdist->{$b} <=> $cosdist->{$a}
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
