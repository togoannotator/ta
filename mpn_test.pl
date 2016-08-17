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

my $sysroot = '/home/tga/togoannotator';

our ($opt_t, $opt_m) = (0.6, 5);
getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.
print "#th:", $opt_t, ", dm:", $opt_m, "\n";

use IO::Compress::Gzip qw(gzip $GzipError) ;

my $dict_gz = 'dict_test.gz';

my $z = new IO::Compress::Gzip($dict_gz)
  or die "gzip failed: $GzipError\n";

my $dict_rows = [];
#before => after
push @$dict_rows, ['hoge protein 1','hoge protein'];
push @$dict_rows, ['hoge protein A','hoge protein'];
push @$dict_rows, ['hoge protein, A','hoge protein'];
push @$dict_rows, ['hoge protein B','hoge protein'];

#R00^I73^I^I^IGlycogen operon protein GlgX homolog^Iglycogen debranching enzyme$
#R00^I240^I^I^IGlycogen operon protein GlgX homolog^IGlgX$
#R00^I241^I^I^IGlycogen operon protein GlgX homolog^IGlgX2$

foreach my $row (@$dict_rows){
  #print Dumper $row;
  $z->print("\t\t\t\t".$row->[1]."\t".$row->[0]."\n");
}

$z->close();


#Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120_with_cyanobase.txt.gz","dict_cyanobacteria_curated.txt");
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, $dict_gz);
Text::TogoAnnotator->openDicts;
match();
Text::TogoAnnotator->closeDicts;

sub match{
  #open(my $IN, $sysroot. '/cyanobase/synechocystis/genes.txt');
    while(<DATA>){
      #next if /^\s*#/;
      chomp;
      #my @vals = split /\t/;
      #next unless $vals[6];
      my $r = Text::TogoAnnotator->retrieve($_);
      print Dumper $r;
      #next if @$r{'match'} eq 'ex';
      #print join("\t",('','','','',@$r{'result'},$vals[6], @$r{'match','info'})),"\n";
      #print join("\t",('',$vals[1],'','',@$r{'result'},$vals[6], @$r{'match','info'})),"\n";
    }
  # close($IN);
}

__DATA__
hoge protein A 
hoge protein B
