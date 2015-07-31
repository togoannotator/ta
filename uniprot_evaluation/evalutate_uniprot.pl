#!/usr/bin/env perl
#
#
my $file ='duplicate_name.txt';
open(IN,$file) or die $!;
my $hash ={};
while(<IN>){
    chomp;
    my($name, $count) = split /\t/;
    $hash->{$name}=$count;
}


while(<>){
    chomp;
    # pid, uniprot/reviewed, embl-cds
    my($sno, $name, $b4name) = split /\t/;
    # 363656
    $chk ='';
    if (defined($hash->{$name}) and $hash->{$name} > 1){
       $chk = 'multiple';
    }elsif ($name =~ m/\Q$b4name\E/i){
      $chk = 'exact';
    }elsif($name =~/Uncharacterized protein/){
      #$chk = 'incorrect';
      $chk = 'invalid';
    }elsif($name =~ m/UPF\d+/){
      #$chk = 'incorrect';
      $chk = 'invalid';
    }elsif($b4name =~/^"(unknown|hypothetical protein|conserved hypothetical protein)"/){
      #$chk = '@@@h';         
      $chk = 'unusable';
    }elsif($b4name =~/^"[^ ]+_[^ ]+"$/){ #locus_tag
        #$chk = '@@@_';
        $chk = 'unusable';
    }else{
      $chk = '@@@';
    }

    #next unless $chk =~/@@@/;
    print join("\t",('',$sno, $chk, '', $name, $b4name, ''))."\n";
}
