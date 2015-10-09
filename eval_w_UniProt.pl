#!/usr/local/bin/perl

# Text::TogoAnnotatorを利用
# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。
# yayamamo 2015/08/19

use warnings;
use strict;
use Fatal qw/open/;
use Getopt::Std;
use lib qw(/opt/services2/togoannot/togoannotator);
use Text::TogoAnnotator;
use PerlIO::gzip;
use utf8;

my $uniprot = "uniprot_evaluation/evalutate_uniprot.txt.gz";

my $sysroot = '/opt/services2/togoannot/togoannotator';
my $evaldir = '20131122_dbcls';

our ($opt_t, $opt_m) = (0.6, 5);
getopt('tm'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

print "#th:", $opt_t, ", dm:", $opt_m, "\n";
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "nite_dictionary_140519mod2_trailSpaceRemoved.txt");
Text::TogoAnnotator->openDicts;
match();
Text::TogoAnnotator->closeDicts;

sub match{

    open(my $UPT, "<:gzip", $sysroot.'/'.$uniprot);
    while(<$UPT>){
	next if /^#/;
	chomp;
	my @vals = split /\t/;
	print join("\t", ("UniProt", @vals));
	my $r = Text::TogoAnnotator->retrieve($vals[5]);
	print "\t", join("\t", ("###", @$r{'match','result','info'})), "\n";
    }
    close($UPT);

}

__END__
