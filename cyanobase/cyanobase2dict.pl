#!/usr/bin/env perl

use Data::Dumper;

my @dir = glob "/var/genome_conf/production/datasets/cyanobase/data_sources/*";
foreach my $ds (@dir){
  my $file = $ds."/data/search_index/definition.tsv";
  warn $file,"\n";
  #         ds:1    dsn:22  g:A9601_00001   c:definition    DNA polymerase III subunit beta
  next unless -f $file; 
  open(IN, $file) or die $!;
  while(<IN>){
     chomp;
     #print $_,"\n";
     my($a, $b, $c, $gene, $type, $value) = split /\t/,;
     $gene =~s/^g://;
     # print join("\t",('null','No.', 'OK', 'change', 'protein name', 'old')),"\n";
     print join("\t",('', $gene,'','', $value, $gene, '#cyanobase')),"\n";
  }
  close(IN);
}

#data/search_index/definition.tsv
