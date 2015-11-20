#!/usr/bin/env perl

print join("\t",('null','No.', 'OK', 'change', 'protein name', 'old')),"\n";
my $h = {};

my $uniprot_emblcds = './cyanobacteria_uniprot_embl.txt.gz';
open my $fh, "gunzip -dc $uniprot_emblcds 2>/dev/null |"
  or die "Can't zcat '$uniprot_emblcds' for reading: $!";
#while(<>){
while ( my $line = <$fh> ) {
  chomp($line);
  my ($uniprot, $emblcds, $uniprot_full, $uniprot_submitted, $embl_product) = split /\t/,$line;
  next if $uniprot eq '"uniprotid"';
  $uniprot_full =~s/(^"|"$)//g;
  $uniprot_submitted =~s/(^"|"$)//g;
  $embl_product =~s/(^"|"$)//g;
  my ($before,$after,$type) = ();
  if($uniprot_full){
    ($before, $after, $type) = ($embl_product, $uniprot_full,'R');
  }else{
    ($before, $after, $type) = ($embl_product, $uniprot_submitted,'U');
    $after = lc($before) eq lc($after) ? $embl_product : $after;
  }
  $h->{"$before @@@ $after"} += 1;
  next if $h->{"$before @@@ $after"} > 1;
  ($after,$guideline_code) = product4ddbj($after);
  next if $before eq $after; ### Todo delete
  #print join("\t",($before, $after, $type .sprintf("%02d",$guideline_code))),"\n";
  print join("\t",($type.sprintf("%02d",$guideline_code),++$i,'','',$after,$before)),"\n";
}
close $fh;

#while (my ($k,$v) = each %$h){
#  print $k,"\t",$v,"\n";
#}

sub product4ddbj {
  my $p = shift @_;
  my $c =0;
#  $p =~ s/^arCOG\d+\s+//;
#  $p =~ s/\((EC|COG).*?\)//;
#  $p =~ s/\s+\w+\d{4,}c?//; # remove possible locus tags
#  $p =~ s/ and (inactivated|related) \w+//;
#  $p =~ s/,\s*family$//;
#  if($p =~/, /){
#     $p = (split(', ', $p))[0]; 
#     ($p,$c) = ($p, $c + 10 * 9);
#  }
  #$p =~ s/^(potential|possible|probable|predicted|uncharacteri.ed)/putative/i;
  if ($p =~/^[A-Z][a-z][a-z][A-Z][0-9]*$/){
	return ("$p protein", 1);
  #}elsif($p =~/^[A-Z]/ and $p !~/^(DNA|RNA|[ACGT][MDT]P|FAD|FMN|NAD|NADP|[A-Z][a-z][a-z][A-Z][0-9]*|P\d+)/){
  #      return (lcfirst($p), '9');
  }elsif ($p =~/^(Uncharacterized protein|hypothetical protein)$/i){
	return ('hypothetical protein',2);
  } else {
	return ($p,0);
  }
  return ($p,$c)
}

# Deoxyribonucleic acid
#        DNA
#        cDNA
#        dsDNA
#        ssDNA
# Ribonucleic acid:
#       dsRNA
#        siRNA
#        snRNA
#        ssRNA
#        tmRNA
#  #Mono-, di-, tri- nucleic acid phosphates:
#        d[ACGT][MDT]P
#        c[AG]MP
#  #Cofactors:
#        FAD
#        FMN
#        NAD
#        NADP
#  #Others:
#        hnRNP  
