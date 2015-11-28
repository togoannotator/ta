#!/usr/local/bin/perl

# Text::TogoAnnotatorを利用したバージョン
# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。
# yayamamo 2014/06/12

use warnings;
use strict;
use Fatal qw/open/;
use Getopt::Std;
#use lib qw(/opt/services2/togoannot/togoannotator);
use lib qw(/home/tga/togoannotator /home/tga/simstring-1.0/swig/perl);
use Text::TogoAnnotator;
use utf8;

my $akuz   = "AKUZ.anno.tab";
my $gohsu  = "GOHSU_genelist.tab_anno.tab.org";
my $gonam  = "GONAM_genelist.tab_anno.tab.org";
my $gs4    = "GS4_genelist.tab_anno_eco.tab.org";
my $val01s = "VAL01S_genelist.tab_anno(original).tab";
my $vez01s = "VEZ01S_genelist.tab_anno(original).tab";
my $verify = "SG25アノテーション確認用_After_10_utf8.txt";

#my $sysroot = '/opt/services2/togoannot/togoannotator';
my $sysroot = '/home/tga/togoannotator';
my $evaldir = '20131122_dbcls';

our ($opt_t, $opt_m) = (0.6, 5);
getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

print "#th:", $opt_t, ", dm:", $opt_m, "\n";
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobaciteria_20151120.txt");
#Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "nite_dictionary_140519mod2_trailSpaceRemoved.txt");
#Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "nite_ALL_1305_99.txt");
Text::TogoAnnotator->openDicts;
match();
Text::TogoAnnotator->closeDicts;

sub match{

    #open(my $VEZ01S, $sysroot.'/'.$evaldir.'/'.$vez01s);
    open(my $CYANO, $sysroot. '/cyanobase/synechocystis/genes.txt');
    while(<$CYANO>){
  next if /^\s*#/;
  chomp;
  my @vals = split /\t/;
  #print join("\t", ("CYANO", @vals[0..6]));
  #print join("\t", ("CYANO", @vals[0..6]));
  my $r = Text::TogoAnnotator->retrieve($vals[6]);
  next if @$r{'match'} eq 'ex';
  #print join("\t",('','','','',@$r{'result'},$vals[6], @$r{'match','info'})),"\n";
  print join("\t",('',$vals[1],'','',@$r{'result'},$vals[6], @$r{'match','info'})),"\n";
  #print "\t", join("\t", (@$r{'match','result','info'})), "\n";
    }
    close($CYANO);

}

__END__
