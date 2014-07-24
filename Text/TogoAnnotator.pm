package Text::TogoAnnotator;

# Yasunori Yamamoto / Database Center for Life Science
# 2013.11.28 辞書ファイル仕様変更による。
# 市川さん>宮澤さんの後任が記載するルールを変えたので、正解データとしてngram掛けるのは、第3タブが○になっているもの、だけではなく、「delとRNA以外」としてください。
# 2013.12.19 前後の"の有無の他に、出典を示す[nite]的な文字の後に"があるものと前に"があるものがあって全てに対応していなかったことに対応。
# 2014.06.12 モジュール化
# getScore関数内で//オペレーターを使用しているため、Perlバージョンが5.10以降である必要がある。

use warnings;
use strict;
use Fatal qw/open/;
use File::Path 'mkpath';
use simstring;

my ($sysroot, $niteAll);
my ($nitealldb_d_name, $nitealldb_e_name);
my ($niteall_d_cs_db, $niteall_e_cs_db);
my ($cos_threshold, $e_threashold, $cs_max, $n_gram);

my @sp_words;
my (%history, %histogram, %convtable);

sub init {
    my $_this = shift;
    $cos_threshold = shift; # cosine距離で類似度を測る際に用いる閾値。この値以上類似している場合は変換対象の候補とする。
    $e_threashold  = shift; # E列での表現から候補を探す場合、辞書中での最大出現頻度がここで指定する数未満の場合のもののみを対象とする。
    $cs_max        = shift; # 複数表示する候補が在る場合の最大表示数
    $n_gram        = shift; # N-gram
    $sysroot       = shift; # 辞書や作業用ファイルを生成するディレクトリ
    $niteAll       = shift; # NITE辞書名

    @sp_words = qw/putative probable possible/;

    # 未定議の場合の初期値
    $cos_threshold //= 0.6;
    $e_threashold //= 30;
    $cs_max //= 5;
    $n_gram //= 3;

    readNITEdict();
}

# NITE辞書の取込み
sub readNITEdict {
    my $dictdir = 'dictionary/cdb_nite_ALL';

    if (!-d  $sysroot.'/'.$dictdir){
	mkpath($sysroot.'/'.$dictdir);
    }

    for my $f ( <${sysroot}/${dictdir}/[de]*> ){
	unlink $f;
    }

    $nitealldb_d_name = $sysroot.'/'.$dictdir.'/d';
    $nitealldb_e_name = $sysroot.'/'.$dictdir.'/e';

    my $niteall_d_db = simstring::writer->new($nitealldb_d_name, $n_gram);
    my $niteall_e_db = simstring::writer->new($nitealldb_e_name, $n_gram);

    my $total = 0;

    open(my $nite_all, $sysroot.'/'.$niteAll);
    while(<$nite_all>){
	chomp;
	my (undef, $sno, $chk, undef, $name, $b4name, undef) = split /\t/;
	next if $chk eq 'RNA' or $chk eq 'del' or $chk eq 'OK';

	$name =~ s/^"\s*//;
	$name =~ s/\s*"\s*$//;
	$b4name =~ s/^"\s*//;
	$b4name =~ s/\s*"\s*$//;

	for ( @sp_words ){
	    $name =~ s/^$_\W+//i;
	}

	my $lcb4name = lc($b4name);
	$lcb4name =~ s{[-/,]}{ }g;
	$lcb4name =~ s/  +/ /g;
	for ( @sp_words ){
	    if(index($lcb4name, $_) == 0){
		$lcb4name =~ s/^$_\s+//;
	    }
	}
	$convtable{$lcb4name} = $name;
	$niteall_e_db->insert($lcb4name);

	my $lcname = lc($name);
	$lcname =~ s{[-/,]}{ }g;
	$lcname =~ s/  +/ /g;
	next if $history{$lcname};
	$history{$lcname} = $name;
	for ( split " ", $lcname ){
	    s/\W+$//;
	    $histogram{$_}++;
	    $total++;
	}
	$niteall_d_db->insert($lcname);
    }
    close($nite_all);

    $niteall_d_db->close;
    $niteall_e_db->close;
}

sub openDicts {
    $niteall_d_cs_db = simstring::reader->new($nitealldb_d_name);
    $niteall_d_cs_db->swig_measure_set($simstring::cosine);
    $niteall_d_cs_db->swig_threshold_set($cos_threshold);
    $niteall_e_cs_db = simstring::reader->new($nitealldb_e_name);
    $niteall_e_cs_db->swig_measure_set($simstring::cosine);
    $niteall_e_cs_db->swig_threshold_set($cos_threshold);
}

sub closeDicts {
    $niteall_d_cs_db->close;
    $niteall_e_cs_db->close;
}

sub retrieve {
    shift;
    my $query = my $oq = shift;
    # $query ||= 'hypothetical protein';
    $query = lc($query);
    $query =~ s/^"\s*//;
    $query =~ s/\s*"\s*$//;
    $query =~ s/\s+\[\w+\]$//;
    $query =~ s/\s*"$//;
    $query =~ s{[-/,]}{ }g;
    $query =~ s/  +/ /g;
    my $prfx = '';
    my ($match, $result, $info) = ('') x 3;
    for ( @sp_words ){
        if(index($query, $_) == 0){
            $query =~ s/^$_\s+//;
	    $prfx = $_. ' ';
	    last;
        }
    }
    if($convtable{$query}){
	# print "\tex\t", $prfx. $convtable{$query}, "\tconvert_from: ", $query;
        $match ='ex';
        $result = $prfx. $convtable{$query};
	$info = 'convert_from: '. $query;
    }else{
	my $retr = $niteall_d_cs_db->retrieve($query);
	my %qtms = map {$_ => 1} grep {s/\W+$//;$histogram{$_}} (split " ", $query);
	if($retr->[0]){
	    my ($minfreq, $minword, $ifhit) = getScore($retr, \%qtms, 1);
	    my %cache;
	    my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /} grep {$cache{$_}++; $cache{$_} == 1} @$retr;
	    my $le = (@out > $cs_max)?($cs_max-1):$#out;
	    # print "\tcs\t", join(" @@ ", (map {$prfx.$history{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
            $match = 'cs';
            $result = $prfx.$history{$out[0]};
            $info   = join(" @@ ", (map {$prfx.$history{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
	}else{
	    my $retr_e = $niteall_e_cs_db->retrieve($query);
	    if($retr_e->[0]){
		my ($minfreq, $minword, $ifhit) = getScore($retr_e, \%qtms, 0);
		my @hits = keys %$ifhit;
		my %cache;
		my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /}
		          grep {$cache{$_}++; $cache{$_} == 1 && $minfreq->{$_} < $e_threashold} @hits;
		my $le = (@out > $cs_max)?($cs_max-1):$#out;
		# print "\tbcs\t", join(" % ", (map {$prfx.$convtable{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
                $match = 'bcs';
                $result = defined $out[0]  ? $prfx.$convtable{$out[0]} : $oq;
                $info   = join(" % ", (map {$prfx.$convtable{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
	    } else {
		# print "\tno_hit\t";
                $match  = 'no_hit';
                $result = $oq;
	    }
	}
    }
    # print "\n";
    return({'query'=> $oq, 'result' => $result, 'match' => $match, 'info' => $info});
}

sub getScore {
    my $retr = shift;
    my $qtms = shift;
    my $minf = shift;
    my (%minfreq, %minword, %ifhit);
    # 対象タンパク質のスコアは、当該タンパク質を構成する単語それぞれにつき、検索対象辞書中での当該単語の出現頻度のうち最小値を割り当てる
    # 最小値を持つ語は $minword{$_} に代入する
    # また、検索タンパク質名を構成する単語が、検索対象辞書からヒットした各タンパク質名に含まれている場合は $ifhit{$_} にフラグが立つ
    for (@$retr){
	my $score = 100000;
	my $word = '';
	my $hitflg = 0;
	for (split){
	    my $h = $histogram{$_} // 0;
	    if($qtms->{$_}){
		$hitflg++;
	    }else{
		$h += 10000;
	    }
	    if($score > $h){
		$score = $h;
		$word = $_;
	    }
	}
	$minfreq{$_} = $score;
	$minword{$_} = $word;
	$ifhit{$_}++ if $hitflg;
    }
    # 検索タンパク質名を構成する単語が、ヒットした各タンパク質名に複数含まれる場合には、その中で検索対象辞書中での出現頻度スコアが最小であるものを採用する
    # そして最小の語のスコアは-1とする。
    my $leastwrd = '';
    my $leastscr = 100000;
    for (keys %ifhit){
	if($minfreq{$_} < $leastscr){
	    $leastwrd = $_;
	    $leastscr = $minfreq{$_};
	}
    }
    if($minf && $leastwrd){
	for (keys %minword){
	    $minfreq{$_} = -1 if $minword{$_} eq $minword{$leastwrd};
	}
    }
    return (\%minfreq, \%minword, \%ifhit);
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
