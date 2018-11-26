#!/usr/bin/env perl

# Text::TogoAnnotatorを利用したバージョン
# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。

use warnings;
use strict;
use Fatal qw/open/;
use Getopt::Std;
use JSON::XS;
#use lib qw(/opt/services2/togoannot/togoannotator);
#use lib qw(/home/tga/togoannotator /home/tga/simstring-1.0/swig/perl);
use FindBin qw($Bin);
use lib "$Bin";
use open qw/:utf8/;
use Text::TogoAnnotator;
use utf8;

my $verify = "product_checklist.txt";

#my $sysroot = '/opt/services2/togoannot/togoannotator';
#my $sysroot = '/home/tga/togoannotator';
my $sysroot = "$Bin";
my $evaldir = 'lee_batch';

$| = 1;

our ($opt_t, $opt_m) = (0.6, 5);
getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

print "#th:", $opt_t, ", dm:", $opt_m, "\n";
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, $evaldir."/dictionary.txt", undef, 0, "lee");
#Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "nite_ALL_1305_99.txt");
Text::TogoAnnotator->openDicts;
match();
Text::TogoAnnotator->closeDicts;

sub match{
    open(my $VRFY, $sysroot.'/'.$verify);
    while(<$VRFY>){
     	chomp;
     	my @vals = split /\t/;
     	print join("\t", ("Lee", @vals[0..1]));
     	my $r = Text::TogoAnnotator->retrieve($vals[0]);
     	print "\t", join("\t", (@$r{'match','result','info'})), "\n";
     }
     close($VRFY);
     return;
}

__END__
