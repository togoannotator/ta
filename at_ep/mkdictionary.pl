#!/bin/env perl

use warnings;
use strict;
use Fatal qw/open/;
use PerlIO::gzip;
use Text::Trim;

my (%uniprot2ena, %uniprot2tax);

open(my $dic, "uniprot2ena_cellular.txt");
while(<$dic>){
  chomp;
  next if length($_) < 165;
  my ($id, $full, $tax);
  $id = substr($_, 0, 82);
  my $htpos = rindex($_, "http://");
  $full = substr($_, 82, ($htpos - 82));
  $tax = substr($_, $htpos);
  trim($id);
  trim($full);
  #print "$full<>$tax\n";
  $uniprot2ena{$id} = $full;
  $uniprot2tax{$id} = $tax;
}
close($dic);

open(my $ena, "<:gzip", "ena_fun_hum_inv_mam_mus_pln_pro_rod_vrt_r127.txt.gz");
while(<$ena>){
  chomp;
  my ($id, $full) = split /\t/;
  $id =~ s/^"//;
  $id =~ s/"$//;
  $full =~ s/^"//;
  $full =~ s/"$//;
  trim($id);
  trim($full);
#  print ">$id<\n";
  next unless defined($uniprot2ena{$id});
  next if $full eq $uniprot2ena{$id};
  print join("\t", ($id, $full, $uniprot2ena{$id}, $uniprot2tax{$id})), "\n";
}
close($ena);

__END__
