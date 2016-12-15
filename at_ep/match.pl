#!/usr/bin/perl

use PerlIO::gzip;
use Fatal qw/open/;

my %pair;

open(my $fh, "<:gzip", "pairs.txt.gz");
while(<$fh>){
    chomp;
    my($id, $product) = split /\t/;
    $pair{$id} = $product;
#    print $id, "---", $product, "\n";
}
close($fh);

open($fh, "uniprot2ena.txt");
while(<$fh>){
    next if index($_, '"emblid"') == 0;
    chomp;
    my($id, $uniprot) = split /\t/;
    my $match = $pair{$id} // "---";
    if($match ne "---"){
	print join("\t", ($id, $uniprot, $match)), "\n";
    }
}
close($fh);

__END__
