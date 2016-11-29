#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Plack::Request;
use JSON;

use FindBin qw($Bin);
use lib "$Bin";
use Text::TogoAnnotator;
use utf8;
use Data::Dumper;

my $sysroot = "$Bin";
our ($opt_t, $opt_m) = (0.6, 5);
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120_with_cyanobase.txt.gz","dict_cyanobacteria_curated.txt");

sub match{
  my @queries = @_;
  my @out = ();
  foreach my $q (@queries){
    my $r = Text::TogoAnnotator->retrieve($q);
    my $json = JSON->new->utf8(0)->encode($r);
    push @out, $json;
  }
  return "[".join(",",@out)."]";
}

sub file2queries {
   my $path = shift;
   my @queries = ();
   open(my $LIST, $path);
   while(<$LIST>){
      chomp;
      next if /^#/;
      push @queries, $_;
   }
   close($LIST);
   return @queries;
}

sub ddbjfile2queries {
    my $path = shift;
    my @queries = ();
    open(my $LIST, $path);
    while(<$LIST>){
      chomp;
      my @a = split "\t",$_;
      if($a[3] eq 'product'){
        push @queries, $a[4];
      }
    }
    return @queries;
}


my $app = sub {
  my $env = shift;
  my $req = Plack::Request->new($env); 
  my @queries = ();
  if ($req->param('query')){
    @queries = $req->param('query');
  }elsif( $req->upload('list')){
    my $upload = $req->upload('list');
    @queries = file2queries($upload->path);
  }elsif( my $upload = $req->upload('ddbj')){ 
    @queries = ddbjfile2queries($upload->path);
  }
  
  # TogoAnnotatorの処理
  Text::TogoAnnotator->openDicts;
  my $body = match(@queries);
  Text::TogoAnnotator->closeDicts;
  
#  my $res = $req->new_response(200);
#  $res->content_type('application/json');
#  my $length = length($body);
#  $res->content_length($length);
#  $res->body([$body]);
#  return $res->finilize;

  return [
    '200',
    [ 'Content-Type' => 'application/json' ],
    [ $body ], # or IO::Handle-like object
  ];

 };

$app;
