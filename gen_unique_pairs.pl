#!/bin/env perl

# 李さんレビュー辞書に対して、1対1対応関係のみのペアを取り出す。
# Curated辞書を出力するので、出力形式は、E列が$before、G列が$afterになる。
# Curated辞書の使い方が、通常の書き換え辞書による書き換え後のデフィニション、つまりE列に対して、G列のものに書き換えるため。

use warnings;
use strict;
use utf8;
use Fatal qw/open/;
use open qw/:utf8/;
use Text::Trim;
use PerlIO::gzip;

my (%f_hash, %r_hash);

open(my $fh, "<:gzip", "/opt/services2/togoannot/togoannotator/data/UniProtLeeCurated.txt.gz");
while(<$fh>){
    chomp;
    my ($after, $before) = @{ [ split /\t/ ] }[4,5];
    $after =~ s/^\'//;
    $after =~ s/\'$//;
    $before =~ s/^\'//;
    $before =~ s/\'$//;
    trim $after;
    trim $before;
    if($r_hash{$after}){
	delete $f_hash{$before};
	next;
    }
    $f_hash{$before} = $after;
    $r_hash{$after} = $before;
}
close($fh);

my $count = 0;
while(my ($before, $after) = each %f_hash){
    $count++;
    print join("\t", ($count, "", "", "", $before, "", $after)), "\n";
}

__END__
