#!/usr/bin/env perl

#use Mojo::Server::Hypnotoad;
#my $hypnotoad = Mojo::Server::Hypnotoad->new;
#my $prefork = $hypnotoad->prefork;
#$hypnotoad  = $hypnotoad->prefork(Mojo::Server::Prefork->new);

use File::Basename;

my $this = basename $0;

my $arg = ($this eq "start_service.pl")?"f":($this eq "stop_service.pl")?"s":"s";

#foreach my $idx (0..3){
foreach my $idx (1..3){
  print $idx,"\n";
  $ENV{'TA_DICT_NO'} = $idx;
  #my $hypnotoad = Mojo::Server::Hypnotoad->new;
  #$hypnotoad->run('./WebService/annotation.pl');
  system("hypnotoad -${arg} ./WebService/annotation.pl &");
  #system("hypnotoad ./WebService/annotation.pl");
}
