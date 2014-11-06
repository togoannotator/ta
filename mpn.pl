#!/usr/local/bin/perl

# Text::TogoAnnotatorを利用したバージョン
# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。
# yayamamo 2014/06/12

use warnings;
use strict;
use Fatal qw/open/;
use Getopt::Std;
use lib qw(/opt/services2/togoannot/togoannotator);
use Text::TogoAnnotator;
use utf8;

my $akuz   = "AKUZ.anno.tab";
my $gohsu  = "GOHSU_genelist.tab_anno.tab.org";
my $gonam  = "GONAM_genelist.tab_anno.tab.org";
my $gs4    = "GS4_genelist.tab_anno_eco.tab.org";
my $val01s = "VAL01S_genelist.tab_anno(original).tab";
my $vez01s = "VEZ01S_genelist.tab_anno(original).tab";
my $verify = "SG25アノテーション確認用_After_10_utf8.txt";

my $sysroot = '/opt/services2/togoannot/togoannotator';
my $evaldir = '20131122_dbcls';

our ($opt_t, $opt_m) = (0.6, 5);
getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

print "#th:", $opt_t, ", dm:", $opt_m, "\n";
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "nite_dictionary_140519mod2_trailSpaceRemoved.txt");
#Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "nite_ALL_1305_99.txt");
Text::TogoAnnotator->openDicts;
match();
Text::TogoAnnotator->closeDicts;

sub match{

    open(my $VRFY, $sysroot.'/'.$verify);
    <$VRFY>;
    while(<$VRFY>){
	chomp;
	my @vals = split /\t/;
	print join("\t", ("SG25", @vals[0..8]));
	my $r = Text::TogoAnnotator->retrieve($vals[8]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($VRFY);

    return;

    open(my $AKUZ, $sysroot.'/'.$akuz);
    while(<$AKUZ>){
	next if /^#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("AKUZ", @vals[0..6]));
	my $r = Text::TogoAnnotator->retrieve($vals[6]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($AKUZ);

    open(my $GOHSU, $sysroot.'/'.$gohsu);
    while(<$GOHSU>){
	next if /^#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("GOHSU", @vals[0..5]));
	my $r = Text::TogoAnnotator->retrieve($vals[5]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($GOHSU);

    open(my $GONAM, $sysroot.'/'.$evaldir.'/'.$gonam);
    while(<$GONAM>){
	next if /^#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("GONAM", @vals[0..5]));
	my $r = Text::TogoAnnotator->retrieve($vals[5]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($GONAM);

    open(my $GS4, $sysroot.'/'.$evaldir.'/'.$gs4);
    while(<$GS4>){
	next if /^#/;
	next if /^ser#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("GS4", @vals[0..5]));
	my $r = Text::TogoAnnotator->retrieve($vals[5]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($GS4);

    open(my $VAL01S, $sysroot.'/'.$evaldir.'/'.$val01s);
    while(<$VAL01S>){
	next if /^#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("VAL01S", @vals[0..5]));
	my $r = Text::TogoAnnotator->retrieve($vals[5]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($VAL01S);

    open(my $VEZ01S, $sysroot.'/'.$evaldir.'/'.$vez01s);
    while(<$VEZ01S>){
	next if /^#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("VEZ01S", @vals[0..5]));
	my $r = Text::TogoAnnotator->retrieve($vals[5]);
	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($VEZ01S);

}

__END__
