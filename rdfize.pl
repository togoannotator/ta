#!/usr/bin/env perl

use warnings;
use strict;
use Fatal qw/open/;
use open ":utf8";
use utf8;
use Encode;
use URI::Escape;
use RDF::Trine;
use Text::Trim;

binmode STDIN, ":utf8";
binmode STDOUT, ":utf8";

my $base_uri = 'http://purl.jp/bio/10/tga/';
my $term_uri_prefix = 'http://purl.jp/bio/10/tga/term/';
my $vocab_uri_prefix = 'http://purl.jp/bio/10/tga/vocabulary#';
my $tgao = RDF::Trine::Namespace->new( $vocab_uri_prefix );
my $rdf = RDF::Trine::Namespace->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' );
my $rdfs = RDF::Trine::Namespace->new( 'http://www.w3.org/2000/01/rdf-schema#' );

my $namespaces = {
  'tgat' => $term_uri_prefix,
  'tgao' => $vocab_uri_prefix
};

my $beforeClass = $tgao->BeforeReplacementTerm;
my $afterClass = $tgao->AfterReplacementTerm;
my $curatedClass = $tgao->CuratedReplacementTerm;
my $replacedBy = $tgao->replacedBy;
my $rdfslabel = $rdfs->label;
my $a = $rdf->type;

my $dummy = <>;
while(<>){
  chomp;
  my @vals = split /\t/;
  if($vals[4] && $vals[5]){
    my $before = trim( $vals[5] );
    my $after = trim( $vals[4] );
    $before =~ s/^"\s*//;
    $before =~ s/\s*"$//;
    $after =~ s/^"\s*//;
    $after =~ s/\s*"$//;
    my $m = RDF::Trine::Model->temporary_model;
    my $uri_s = RDF::Trine::Node::Resource->new($term_uri_prefix.uri_escape(encode_utf8($vals[5])));
    my $uri_d = RDF::Trine::Node::Resource->new($term_uri_prefix.uri_escape(encode_utf8($vals[4])));
    my $uri_s_label = RDF::Trine::Node::Literal->new( encode_utf8($vals[5]) );
    my $uri_d_label = RDF::Trine::Node::Literal->new( encode_utf8($vals[4]) );
    $m->add_statement( RDF::Trine::Statement->new($uri_s, $a, $beforeClass) );
    $m->add_statement( RDF::Trine::Statement->new($uri_s, $rdfslabel, $uri_s_label) );
    $m->add_statement( RDF::Trine::Statement->new($uri_d, $a, $afterClass) );
    $m->add_statement( RDF::Trine::Statement->new($uri_d, $rdfslabel, $uri_d_label) );
    $m->add_statement( RDF::Trine::Statement->new($uri_s, $replacedBy, $uri_d) );
    my $s = RDF::Trine::Serializer::NTriples->new();
    #my $s = RDF::Trine::Serializer::Turtle->new( namespaces => $namespaces );
    #my $s = RDF::Trine::Serializer::Turtle->new( namespaces => {tgat => $term_uri_prefix} );
    print $s->serialize_model_to_string( $m );
    # print "\n";
  }
}

__END__
