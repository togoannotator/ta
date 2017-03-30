#!/usr/bin perl

use JSON;
use File::Basename;
use Search::Elasticsearch;
use Digest::MD5::Reverse;

# Connect to localhost:9200:
my $e = Search::Elasticsearch->new();

#$e->indices->delete(index=>'dev_dd2f74a1041db59c64a665b356c9d1b3');
@files = qw(dictionary/convtable.txt  dictionary/correct_definitions.txt dictionary/wospconvtableD.txt  dictionary/wospconvtableE.txt);

foreach my $file (@files){
  print $file,"\n";
  my $type = basename($file,".txt");
  my $i = 0;
  open(IN, $file) or die $!;
  while(<IN>){
    #last if $i++ >= 1000;
    chomp;
    my $name ='';
    my $frequencey = 0;
    my ($id, $tkey, $tvalue, $dictionary) =split /\t/;
    next if $tkey eq 'tkey';
    if( $tvalue =~/^\{(.+)\:\s+(.+)\}$/){
      my $json = from_json($tvalue, {utf8 => 1});
      $name = (keys %$json)[0];
      $frequency = (values %$json)[0];
    }else{
      $name = $tvalue;
    }
    #my $doc = {'index' => $dictionary, 'type' => $type, 'id' => $id, 'body' => {'name' => $name, 'normalized_name' => $tkey, 'frequency' => $frequency}};
    #print to_json($doc),"\n";
    #$e->index( index => "dev_".$dictionary, type => $type, id => $id, body => { name => $name, normalized_name => $tkey, frequency => $frequency });
    $e->index( index => "dict_".$dictionary, type => $type, id => $id, body => { name => $name, normalized_name => $tkey, frequency => $frequency });
  }
  close(IN);
}  

#my $dictonary_string = reverse_md5($dictionary);
#print $dictionary_string,"\n";

#$e->indices->create(index=> 'ta_'. $dictonary_string, body=>{ aliases=>['dev_dd2f74a1041db59c64a665b356c9d1b3']})

