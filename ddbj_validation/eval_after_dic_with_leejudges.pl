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

my $matcher = Text::Match::FastAlternatives->new( @dictionary );

my %levels;

open(my $leejudge, "check_wordsNotInDictionary_ENA_2_ReviewedUniProt.txt");
while(<$leejudge>){
    chomp;
    trim($_);
    my ($w, $s, $j) = split /\t/;
    next if $j eq "level";
    $levels{$w} = $j;
}
close($leejudge);

my (%afters, %eid2lct);

open(my $locustag, "../uniprot_evaluation/Embl2LocusTag.txt");
while(<$locustag>){
    chomp;
    my ($eid, $lct) = split /\t/;
    next if $eid eq '"emblid"';
    $lct =~ s/^"//;
    $lct =~ s/"$//;
    push @{ $eid2lct{$eid} }, $lct;
}
close($locustag);

open(my $tgd, "<:gzip", "../uniprot_evaluation/matched.txt.gz");
while(<$tgd>){
    chomp;
    my ($id, $af, $bf) = split /\t/;
    $af =~ s/^"//;
    $af =~ s/"$//;
    $bf =~ s/^"//;
    $bf =~ s/"$//;
    trim( $af );
    my $origin = $af;
    $af =~ y|-()[]/,| |;
    $af =~ s/\'/ /g;
    $af =~ s/  +/ /g;
    trim( $af );
    my @lct;
    next if $afters{$af};
    if( $eid2lct{$id} ){
	for ( @{ $eid2lct{$id} } ){
	    if(index($af, $_) > -1){
		$af =~ s/\b$_\b//;
		$af =~ s/  +/ /g;
		trim( $af );
		push @lct, $_;
	    }
	}
    }
    next if $afters{$af};
    $afters{$af}++;
    my %hash;
    for (split / /, $af) {
	$hash{2}++ if $matcher->exact_match($_);
	$hash{$levels{$_}}++ if defined($levels{$_});
    }
    my $result = join("", (sort {$a <=> $b} keys %hash));
    print join("\t", ($af, $result, "[". join(":", @lct). "]", $origin, $bf)), "\n";
}
close($tgd);

__END__
