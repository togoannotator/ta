#!/usr/bin/env perl

#use Mojo::Server::Hypnotoad;
#my $hypnotoad = Mojo::Server::Hypnotoad->new;
#my $prefork = $hypnotoad->prefork;
#$hypnotoad  = $hypnotoad->prefork(Mojo::Server::Prefork->new);

#foreach my $idx (0..3){
foreach my $idx (1..3){
  print $idx,"\n";
  $ENV{'TA_DICT_NO'} = $idx;
  #my $hypnotoad = Mojo::Server::Hypnotoad->new;
  #$hypnotoad->run('./WebService/annotation.pl');
  #system("hypnotoad -f ./WebService/annotation.pl");
  system("hypnotoad ./WebService/annotation.pl");
}
