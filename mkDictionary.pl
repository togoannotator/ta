#!/usr/bin/env perl

use warnings;
use strict;
use Fatal qw/open/;
use Getopt::Std;
use FindBin qw($Bin);
use lib "$Bin";
use Text::TogoAnnotator;
use utf8;

my $sysroot = "$Bin";

our ($opt_t, $opt_m) = (0.6, 5);
if( $ARGV[0] ){
    Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, $ARGV[0], "", 1); 
}

__END__
