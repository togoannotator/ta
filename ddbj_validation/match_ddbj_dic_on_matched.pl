#!/usr/bin/env perl

use warnings;
use strict;
use Fatal qw/open/;
use PerlIO::gzip;
use Text::Trim;
use Text::Match::FastAlternatives;
use JSON::XS;

my @dictionary;
#open(my $dic, "20151118_words.txt"); #オリジナル時に利用した辞書
open(my $dic, "word_20161215.txt");
while(<$dic>){
    chomp;
    trim;
    push @dictionary, lc($_);
}
close $dic;

my %match_history;
my $matcher = Text::Match::FastAlternatives->new( @dictionary );
open(my $tgd, "<:gzip", "../uniprot_evaluation/matched.txt.gz");
while(<$tgd>){
    chomp;
    my ($id, $af, $bf) = split /\t/;
    my (@matched, @unmatched);
    $af =~ s/^"//;
    $af =~ s/"$//;
    trim( $af );
    my $origin = $af;
    $af =~ y|-()[]/,| |;
    $af =~ s/\'/ /g;
    $af =~ s/  +/ /g;
    trim( $af );
    for ( split / /, $af ){
        if( $matcher->exact_match(lc $_) ){
            push @matched, $_;
            $match_history{$_}++;
        } else {
	    push @unmatched, $_;
	}
    }
    # print join("\t", ($origin, $af, "|".join(":", @matched)."|")), "\n"; # オリジナルバージョン
    #print join("\t", ($origin, $origin, (scalar @unmatched), encode_json(\@unmatched), $af)), "\n"; # 7/3のDDBJでのミーティングを踏まえた、OpenRefine用の出力
    print join("\t", ($origin, $origin, (scalar @unmatched), join(" ", @unmatched), $af)), "\n"; # 7/3のDDBJでのミーティングを踏まえた、OpenRefine用の出力
}
close($tgd);

# 以下はオリジナルの時に利用したヒストグラム出力用で、OpenRefine向けには不要
exit;

for ( sort {$match_history{$b} <=> $match_history{$a}} keys %match_history ){
    print join("\t", ("H", $_, $match_history{$_})), "\n";
}

__END__
