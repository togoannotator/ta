#!/usr/bin/env perl

use warnings;
use strict;
use Fatal qw/open/;
use PerlIO::gzip;
use Text::Trim;
use Text::Match::FastAlternatives;

my @dictionary;
open(my $dic, "20151118_words.txt");
while(<$dic>){
    chomp;
    trim;
    push @dictionary, $_;
}
close $dic;

my %match_history;
my $matcher = Text::Match::FastAlternatives->new( @dictionary );
open(my $tgd, "<:gzip", "../uniprot_evaluation/matched.txt.gz");
while(<$tgd>){
    chomp;
    my ($id, $af, $bf) = split /\t/;
    my @matched;
    $af =~ s/^"//;
    $af =~ s/"$//;
    trim( $af );
    my $origin = $af;
    $af =~ y|-()[]/,| |;
    $af =~ s/\'/ /g;
    $af =~ s/  +/ /g;
    trim( $af );
    for ( split / /, $af ){
        if( $matcher->exact_match($_) ){
            push @matched, $_;
            $match_history{$_}++;
        }
    }
    print join("\t", ($origin, $af, "|".join(":", @matched)."|")), "\n";
}
close($tgd);

for ( sort {$match_history{$b} <=> $match_history{$a}} keys %match_history ){
    print join("\t", ("H", $_, $match_history{$_})), "\n";
}

__END__
