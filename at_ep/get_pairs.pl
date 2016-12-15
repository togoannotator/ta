#!/usr/bin/perl

use warnings;
use strict;
use Fatal qw/open/;

my ($cdsflg, $cont);
my %pair;

while(<>){
    if($cdsflg && /^XX/){
	if($cdsflg){
	    print join("\t", values %pair),"\n" if scalar values %pair==2;
	    %pair=();
	}
	$cdsflg = 0;
    }elsif(/^FT\s{3}(\w+)/){
	if($cdsflg){
	    print join("\t", values %pair),"\n" if scalar values %pair==2;
	    %pair=();
	}
	$cdsflg = ($1 eq "CDS");
    }elsif($cdsflg && m,^FT\s{19}/(product|protein_id)=(.+)$,){
	$pair{$1}=$2;
	$cont = ($2 !~ m,"$,);
    }elsif($cdsflg && $cont && m,^FT\s{19}([^/].+)$,){
	$pair{"product"} .= " ".$1;
	$cont = ($1 !~ m,"$,);
    }
}

__END__
