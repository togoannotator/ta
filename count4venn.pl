#!/usr/local/bin/perl

# Text::TogoAnnotatorを利用
# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。
# yayamamo 2015/08/19
#
# UniProtの結果とTogoAnnotatorの結果を出力できるように修正。
# Levenshtein距離による、UniProtの結果とTogoAnnotatorの結果の比較出力も対応。
# yayamamo 2015/10/15

use warnings;
use strict;
use Fatal qw/open/;
use PerlIO::gzip;
use utf8;
use File::Spec;
use File::Basename;
use Text::Levenshtein::Flexible qw/levenshtein_l_all/;

my $uniprot = "uniprot_evaluation/evalutate_uniprot.txt.gz";
#my $sysroot = '/opt/services2/togoannot/togoannotator';
my $sysroot = dirname(File::Spec->rel2abs(__FILE__));
my $nitedic = "nite_dictionary_140519mod2_trailSpaceRemoved.txt";
my $togoannot = "uniprot_evaluation/eval_result_w_UniProt_20150819.txt.gz";
my $keywords = "uniprot_evaluation/uniprot2enaWkeywords.txt.gz";

binmode STDOUT, ":encoding(utf8)";

my (%nitedicFor, %nitedicRev);
my (%uniprotFor, %uniprotRev);
my (%uniprotKeywords, %enaid);
my (%togoannotFor, %togoannotRev, %togoannotMatch);
my (%sum);

# タブ区切り: "emblid", "keyword_uri", "keyword"
# 例: "ABK36159.1", "http://purl.uniprot.org/keywords/46", "Antibiotic resistance"
open(my $KWF, "<:gzip", $sysroot.'/'.$keywords);
while(<$KWF>){
    next if /^"emblid"/;
    chomp;
    my ($eid, $uri, $keyword) = split /\t/;
    $keyword =~ s/^"//;
    $keyword =~ s/"$//;
    push @{$uniprotKeywords{$eid}}, $keyword;
}
close($KWF);

open(my $DICT, $sysroot.'/'.$nitedic);
while(<$DICT>){
    chomp;
    my (undef, $sno, $chk, undef, $after, $before, undef) = split /\t/;
    next if $chk eq 'RNA' or $chk eq 'del' or $chk eq 'OK';
    $before = lc($before);
    $after = lc($after);
    $nitedicFor{$before}{$after}++;
    $nitedicRev{$after}{$before}++;
}
close($DICT);

print join("\t", ("STAT_NITE", scalar keys %nitedicFor, scalar keys %nitedicRev)), "\n";

while(my ($k, $v) = each %nitedicFor){
    if($nitedicRev{$k}){
	print join("\t", ("NITE", $k, "|", keys %$v, "|", keys %{$nitedicRev{$k}})), "\n";
    }
    for ( keys %$v ){
	next if $k eq $_;
	if($nitedicFor{$_}){
	    for my $t ( keys %{$nitedicFor{$_}} ){
		next if $_ eq $t;
		print join("\t", ("TRANS_NITE", $k, "->", $_, "->", $t)), "\n";
	    }
	}
    }
}

open(my $UPT, "<:gzip", $sysroot.'/'.$uniprot);
while(<$UPT>){
    next if /^#/;
    chomp;
    my (undef, $eid, undef, undef, $after, $before) = split /\t/;
    $after =~ s/^"//;
    $after =~ s/"$//;
    $before =~ s/^"//;
    $before =~ s/"$//;
    $before = lc($before);
    $after = lc($after);
    $uniprotFor{$before}{$after}++;
    $uniprotRev{$after}{$before}++;
    $enaid{$before} = $eid;
}
close($UPT);

open(my $tga, "<:gzip", $sysroot.'/'.$togoannot);
while(<$tga>){
    next if index($_, "UniProt") != 0;
    chomp;
    my (undef, undef, $eid, $type, undef, $after, $before, undef, $tga_matchtype, $tga_after, $tga_comments) = split /\t/;
    $before =~ s/^"//;
    $before =~ s/"$//;
    $tga_after =~ s/^"//;
    $tga_after =~ s/"$//;
    $before = lc($before);
    $tga_after = lc($tga_after);

    $togoannotFor{$before}{$tga_after}++;
    $togoannotRev{$tga_after}{$before}++;
    $togoannotMatch{$before,$tga_after}{type} = $tga_matchtype;
    $togoannotMatch{$before,$tga_after}{comments} = $tga_comments;
}
close($tga);

print join("\t", ("STAT_UniProt", scalar keys %uniprotFor, scalar keys %uniprotRev)), "\n";

# TogoAnnotatorの変換後のデフィニションとUniProtKBのそれを比較する。
my %history;
while(my ($k, $v) = each %uniprotFor){ # UniProt (ena -> UniProtKB)において、$k -> $v
    if($togoannotFor{$k}){ # TogoAnnotatorにおいて、$k -> 何か
	my $kws = $uniprotKeywords{$enaid{$k}}? join(" # ", sort @{$uniprotKeywords{$enaid{$k}}}) : "";
	my @uniprot_after_set = keys %$v;
	my $hitflag = "";
	# TogoAnnotatorにおいて $k で示されるenaのデフィニションに対応する
	# 変換後の各デフィニション = keys %{$togoannotFor{$k}}
	#
	# $hitflagにTogoAnnotatorの変換後のデフィニションがUniProtKBと
	# 同一であるか否かが入力される。
	#
	# 更に、TogoAnnotatorにおけるマッチのタイプ (ex/cs/delなど) と
	# UniProtKBとの一致の有無 (oかx)、そして変換後のデフィニションが
	# コロンで結ばれた文字列が @mr に代入される。
	my @mr = map {
	    $hitflag ||= defined($uniprotFor{$k}{$_});
	    unless(defined($history{$_})){
		$history{$_}++;
		$sum{$_} += 10000;
	    };
	    $togoannotMatch{$k,$_}{type}.":".($uniprotFor{$k}{$_}?"o":"x").":".$_;
	} keys %{$togoannotFor{$k}};
	print join("\t", ("TogoAnnot", $kws, $k, "|", @uniprot_after_set, "|", join(" % ", @mr))), "\n";
	# もしもTogoAnnotatorによる変換後のデフィニションがUniProtKBと
	# 一致しない場合は、編集距離で2以内で一致するか否かを確認する。
	if(!$hitflag){
	    for ( keys %{$togoannotFor{$k}} ){
		my @distance = map { $_->[0] } sort { $a->[1] <=> $b->[1] } levenshtein_l_all(2, $_ ,keys %$v);
		if(@distance){
		    print join("\t", ("TogoAnnotDistance", $_, "|", @distance)), "\n";
		}
	    }
	}
    }
    if($uniprotRev{$k}){
	print join("\t", ("UniProt", $k, "|", keys %$v, "|", keys %{$uniprotRev{$k}})), "\n";
    }
    for ( keys %$v ){
	next if $k eq $_;
	if($uniprotFor{$_}){
	    for my $t ( keys %{$uniprotFor{$_}} ){
		next if $_ eq $t;
		print join("\t", ("TRANS_UniProt", $k, "->", $_, "->", $t)), "\n";
	    }
	}
    } 
}

while(my ($k, $v) = each %nitedicFor){
    $sum{$k} += 1;
    if($uniprotFor{$k}){
	print join("\t", ("Equal_Before", $k)), "\n";
    }
}

while(my ($k, $v) = each %nitedicRev){
    $sum{$k} += 10;
    if($uniprotRev{$k}){
	print join("\t", ("Equal_After", $k)), "\n";
    }
}

while(my ($k, $v) = each %uniprotFor){
    $sum{$k} += 100;
}

while(my ($k, $v) = each %uniprotRev){
    $sum{$k} += 1000;
}

while(my ($k, $v) = each %sum){
    print join("\t", ('SUM_'. sprintf("%05d",$v), $k)) ,"\n";
}

__END__
