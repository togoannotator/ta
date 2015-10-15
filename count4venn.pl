#!/usr/local/bin/perl

# Text::TogoAnnotatorを利用
# Emacsが適切に本ファイルの文字コード(UTF8)を判断できるようにして書き込みしておく。
# yayamamo 2015/08/19

use warnings;
use strict;
use Fatal qw/open/;
use PerlIO::gzip;
use utf8;

my $uniprot = "uniprot_evaluation/evalutate_uniprot.txt.gz";
my $sysroot = '/opt/services2/togoannot/togoannotator';
my $nitedic = "nite_dictionary_140519mod2_trailSpaceRemoved.txt";

binmode STDOUT, ":encoding(utf8)";

my (%nitedicFor, %nitedicRev);
my (%uniprotFor, %uniprotRev);
my %uniprotKeywords;

open(my $DICT, $sysroot.'/'.$nitedic);
while(<$DICT>){
  chomp;
  my (undef, $sno, $chk, undef, $after, $before, undef) = split /\t/;
  next if $chk eq 'RNA' or $chk eq 'del' or $chk eq 'OK';
  $before = lc($before);
  $after = lc($after);
  $nitedicFor{$before}{$after}++;
  $nitedicRev{$after}{$before}++;
}
close($DICT);

print join("\t", ("STAT_NITE", scalar keys %nitedicFor, scalar keys %nitedicRev)), "\n";

while(my ($k, $v) = each %nitedicFor){
  if($nitedicRev{$k}){
    print join("\t", ("NITE", $k, "|", keys %$v, "|", keys %{$nitedicRev{$k}})), "\n";
  }
  for ( keys %$v ){
    next if $k eq $_;
    if($nitedicFor{$_}){
      for my $t ( keys %{$nitedicFor{$_}} ){
	next if $_ eq $t;
	print join("\t", ("TRANS_NITE", $k, "->", $_, "->", $t)), "\n";
      }
    }
  }
}

open(my $UPT, "<:gzip", $sysroot.'/'.$uniprot);
while(<$UPT>){
  next if /^#/;
  chomp;
  my (undef, $eid, undef, undef, $after, $before) = split /\t/;
  $after =~ s/^"//;
  $after =~ s/"$//;
  $before =~ s/^"//;
  $before =~ s/"$//;
  $before = lc($before);
  $after = lc($after);
  $uniprotFor{$before}{$after}++;
  $uniprotRev{$after}{$before}++;
  $uniprotKeywords{$before} = $eid;
}
close($UPT);

print join("\t", ("STAT_UniProt", scalar keys %uniprotFor, scalar keys %uniprotRev)), "\n";

while(my ($k, $v) = each %uniprotFor){
  if($uniprotRev{$k}){
    print join("\t", ("UniProt", $uniprotKeywords{$k}.":".$k, "|", keys %$v, "|", keys %{$uniprotRev{$k}})), "\n";
  }
  for ( keys %$v ){
    next if $k eq $_;
    if($uniprotFor{$_}){
      for my $t ( keys %{$uniprotFor{$_}} ){
	next if $_ eq $t;
	print join("\t", ("TRANS_UniProt", $k, "->", $_, "->", $t)), "\n";
      }
    }
  } 
}

while(my ($k, $v) = each %nitedicFor){
  if($uniprotFor{$k}){
    print join("\t", ("Equal_Before", $k)), "\n";
  }
}

while(my ($k, $v) = each %nitedicRev){
  if($uniprotRev{$k}){
    print join("\t", ("Equal_After", $k)), "\n";
  }
}

__END__
