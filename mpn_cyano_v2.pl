#!/usr/bin/env perl

# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。
# yayamamo 2014/06/12

use warnings;
use strict;
use Fatal qw/open/;
use Getopt::Std;
#use lib qw(/home/tga/togoannotator /home/tga/simstring-1.0/swig/perl);
use FindBin qw($Bin);
use lib "$Bin";
use Text::TogoAnnotator;
use utf8;
use Data::Dumper;

#my $sysroot = '/home/tga/togoannotator';
my $sysroot = "$Bin";

our ($opt_t, $opt_m) = (0.6, 5);
getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

print "#th:", $opt_t, ", dm:", $opt_m, "\n";
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120_with_cyanobase.txt.gz");
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120_with_cyanobase.txt.gz","dict_cyanobacteria_curated.txt");
Text::TogoAnnotator->openDicts;
match();
Text::TogoAnnotator->closeDicts;

sub match{
    open(my $CYANO, $sysroot. '/cyanobase/synechocystis/genes.txt');
    while(<$CYANO>){
  next if /^\s*#/;
  chomp;
  my @vals = split /\t/;
  next unless $vals[6];
  my $r = Text::TogoAnnotator->retrieve($vals[6]);
  #print Dumper $r;
  #next if @$r{'match'} eq 'ex';
  #print join("\t",('','','','',@$r{'result'},$vals[6], @$r{'match','info'})),"\n";
  print join("\t",('',$vals[1],'','',@$r{'result'},$vals[6], @$r{'match','info'})),"\n";
  #print "\t", join("\t", (@$r{'match','result','info'})), "\n";
#$VAR1 = {
#          'info' => 'in_dictionary: solanesyl diphosphate synthase',
#          'query' => 'solanesyl diphosphate synthase',
#          'match' => 'ex',
#          'result_array' => [
#                              'solanesyl diphosphate synthase'
#                            ],
#          'result' => 'solanesyl diphosphate synthase'
#        };


    }
    close($CYANO);

}

__END__
