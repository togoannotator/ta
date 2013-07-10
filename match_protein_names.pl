#!/usr/local/bin/perl

# Yasunori Yamamoto / Database Center for Life Science
# 2013.05.20

use warnings;
use strict;
use Fatal qw/open/;
use simstring;
use Getopt::Std;

my $niteAll = "nite_ALL_130517.txt";
my $akuz = "AKUZ.anno.tab";
my $gohsu = "GOHSU_genelist.tab_anno.tab.org";

my @sp_words = qw/putative probable possible/;

my $sysroot = '/opt/services2/yayamamo/NITE/';
my $cos_threshold = 0.6; # cosine距離で類似度を測る際に用いる閾値。この値以上類似している場合は変換対象の候補とする。
my $e_threashold = 30;   # E列での表現から候補を探す場合、辞書中での最大出現頻度がここで指定する数未満の場合のもののみを対象とする。
my $cs_max = 5;          # 複数表示する候補が在る場合の最大表示数
my $n_gram = 3;          # 3: trigram

our ($opt_t, $opt_m);

getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

$cos_threshold = $opt_t if $opt_t;
$cs_max = $opt_m if $opt_m;

print "#th:", $cos_threshold, ", dm:", $cs_max, "\n";

for my $f ( <${sysroot}/cdb_nite_ALL/[de]*> ){
    unlink $f;
}

my $nitealldb_d_name = $sysroot.'cdb_nite_ALL/d';
my $nitealldb_e_name = $sysroot.'cdb_nite_ALL/e';

my $niteall_d_db = simstring::writer->new($nitealldb_d_name, $n_gram);
my $niteall_e_db = simstring::writer->new($nitealldb_e_name, $n_gram);

my (%history, %histogram, %convtable);
my $total = 0;

open(my $nite_all, $sysroot.$niteAll);
while(<$nite_all>){
    chomp;
    my (undef, $sno, $chk, undef, $name, $b4name, undef) = split /\t/;
    next unless $chk eq 'o';

    $name =~ s/^"//;
    $name =~ s/"$//;
    $b4name =~ s/^"//;
    $b4name =~ s/"$//;

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

my $niteall_d_cs_db = simstring::reader->new($nitealldb_d_name);
$niteall_d_cs_db->swig_measure_set($simstring::cosine);
$niteall_d_cs_db->swig_threshold_set($cos_threshold);
my $niteall_e_cs_db = simstring::reader->new($nitealldb_e_name);
$niteall_e_cs_db->swig_measure_set($simstring::cosine);
$niteall_e_cs_db->swig_threshold_set($cos_threshold);

open(my $AKUZ, $sysroot.$akuz);
while(<$AKUZ>){
    next if /^#/;
    chomp;
    my @vals = split /\t/;
    print join("\t", ("AKUZ", @vals[0..6]));
    my $query = $vals[6];
    retrieve($query);
}
close($AKUZ);

open(my $GOHSU, $sysroot.$gohsu);
while(<$GOHSU>){
    next if /^#/;
    chomp;
    my @vals = split /\t/;
    print join("\t", ("GOHSU", @vals[0..5]));
    (my $query = $vals[5]) =~ s/ \[\w+\]$//;
    retrieve($query);
}
close($GOHSU);

$niteall_d_cs_db->close;
$niteall_e_cs_db->close;

sub retrieve {
    my $query = shift;
    $query = lc($query);
    $query =~ s{[-/,]}{ }g;
    $query =~ s/  +/ /g;
    my $prfx = '';
    for ( @sp_words ){
        if(index($query, $_) == 0){
            $query =~ s/^$_\s+//;
	    $prfx = $_. ' ';
	    last;
        }
    }
    if($convtable{$query}){
	print "\tex\t", $prfx. $convtable{$query};
    }else{
	my $retr = $niteall_d_cs_db->retrieve($query);
	my %qtms = map {$_ => 1} grep {s/\W+$//;$histogram{$_}} (split " ", $query);
	if($retr->[0]){
	    my ($minfreq, $minword, $ifhit) = getScore($retr, \%qtms, 1);
	    my %cache;
	    my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /} grep {$cache{$_}++; $cache{$_} == 1} @$retr;
	    my $le = (@out > $cs_max)?($cs_max-1):$#out;
	    print "\tcs\t", join(" @@ ", (map {$prfx.$history{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
	}else{
	    my $retr_e = $niteall_e_cs_db->retrieve($query);
	    if($retr_e->[0]){
		my ($minfreq, $minword, $ifhit) = getScore($retr_e, \%qtms, 0);
		my @hits = keys %$ifhit;
		my %cache;
		my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /}
		          grep {$cache{$_}++; $cache{$_} == 1 && $minfreq->{$_} < $e_threashold} @hits;
		my $le = (@out > $cs_max)?($cs_max-1):$#out;
		print "\tbcs\t", join(" % ", (map {$prfx.$convtable{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
	    } else {
		print "\tno_hit\t";
	    }
	}
    }
    print "\n";
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
