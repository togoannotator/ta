#!/usr/bin/env perl


use Data::Dumper;

my $hash ={};
while(<>){
    chomp;
    # pid, uniprot/reviewed, embl-cds
    my($sno, $name, $b4name) = split /\t/;
    $hash->{$b4name}->{$name} += 1;
    #next unless $chk =~/@@@/;
    #print join("\t",('',$sno, $chk, '', $name, $b4name, ''))."\n";
}

#print Dumper $hash;
foreach my $k (keys %$hash){
    my $count = scalar(values(%{$hash->{$k}})); 
    next if $count <= 1;
    print $k ,"\t", $count, "\n";
    #print Dumper $hash->{$k};
}
