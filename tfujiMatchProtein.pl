#!/usr/local/bin/perl

# Yasunori Yamamoto / Database Center for Life Science
# 2013.05.20
# Takatomo Fujisawa / National Institute of Genetics
# 2013.12.25
# sample: 
#     perl match_protein_names.pl -f data/test/annotation_default.ttl
#     perl match_protein_names.pl -f data/test/genes.txt 
#              -d: dictionary (default: nite_ALL_130517.txt)
#              -f: ta_query file
#              -m: cs_max (default: 5)
#              -n: column No. of id and entity in tsv (default: 1,6 for genes.txt)
#              -o: output format (tsv or ttl)
#              -m: cs_max (default: 5)        # TogoAnnotator
#              -t: cos_threshold (default: 3) # TogoAnnotator
#              -v: verbose mode

use warnings;
use strict;
use Fatal qw/open/;
use simstring;
use Getopt::Std;
use File::Basename;
use File::Spec;
use JSON;
use DateTime;
use File::Path 'mkpath';

###  setting for genome refine #################
my $base_uri = 'http://genome.microbedb.jp/';
# /var/genome_conf/staging/tconf/236/data_sources/GR16/genome.ttl
#my $genome_conf = '/var/genome_conf/staging/tconf';
################################################


use Data::UUID;
use Date::Format;
our $ug    = new Data::UUID;



our ($opt_t, $opt_m, $opt_d, $opt_f, $opt_c, $opt_n, $opt_o, $opt_v);
getopt('tmdfon'); # -tm take arg.  Sets $opt_t, $opt_m as a side effect.

my $ta_dictionary = $opt_d || "dictionary/nite_ALL_130517.txt"; # d: dictionary
my $ta_query = $opt_f || '/var/genome_conf/staging/tconf/235/data_sources/GR15/annotation_default.ttl';
my ($filename, $path, $suffix) = fileparse($ta_query, qw/tsv csv txt ttl/);
grep(/^$suffix$/, qw/tsv csv txt ttl/) or die "use csv, tsv or ttl format"; 
$opt_o ||= $suffix;
$opt_n ||= "1,6";
my($id_n, $entity_n) = split /,/, $opt_n;
my @sp_words = qw/putative probable possible/;

my $sysroot = File::Spec->rel2abs(dirname(dirname(__FILE__)))."/";

my $cos_threshold = 0.6; # cosine距離で類似度を測る際に用いる閾値。この値以上類似している場合は変換対象の候補とする。
my $e_threashold = 30;   # E列での表現から候補を探す場合、辞書中での最大出現頻度がここで指定する数未満の場合のもののみを対象とする。
my $cs_max = 5;          # 複数表示する候補が在る場合の最大表示数
my $n_gram = 3;          # 3: trigram

$cos_threshold = $opt_t if $opt_t;
$cs_max = $opt_m if $opt_m;

#print "#th:", $cos_threshold, ", dm:", $cs_max, "\n";
print '@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix oa: <http://www.w3.org/ns/oa#> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix cnt: <http://www.w3.org/2011/content#> .
@prefix gref: <http://genome.microbedb.jp/ontologies/genomerefine#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix prov: <http://www.w3.org/ns/prov#> .
'."\n";


if (!-d  $sysroot.'dictionary/cdb_nite_ALL'){
    mkpath($sysroot.'dictionary/cdb_nite_ALL');
}

for my $f ( <${sysroot}/dictionary/cdb_nite_ALL/[de]*> ){
    unlink $f;
}

my $nitealldb_d_name = $sysroot.'dictionary/cdb_nite_ALL/d';
my $nitealldb_e_name = $sysroot.'dictionary/cdb_nite_ALL/e';

my $niteall_d_db = simstring::writer->new($nitealldb_d_name, $n_gram);
my $niteall_e_db = simstring::writer->new($nitealldb_e_name, $n_gram);

my (%history, %histogram, %convtable);
my $total = 0;

open(my $nite_all, $sysroot.$ta_dictionary);
while(<$nite_all>){
    chomp;
    my (undef, $sno, $chk, undef, $name, $b4name, undef) = split /\t/;
    next unless $chk eq 'o';

    $name =~ s/^"//;
    $name =~ s/"$//;
    $b4name =~ s/^"//;
    $b4name =~ s/"$//;

    for ( @sp_words ){
	$name =~ s/^$_\W+//i;
    }

    my $lcb4name = lc($b4name);
    $lcb4name =~ s{[-/,]}{ }g;
    $lcb4name =~ s/  +/ /g;
    for ( @sp_words ){
	if(index($lcb4name, $_) == 0){
	    $lcb4name =~ s/^$_\s+//;
	}
    }
    $convtable{$lcb4name} = $name;
    $niteall_e_db->insert($lcb4name);

    my $lcname = lc($name);
    $lcname =~ s{[-/,]}{ }g;
    $lcname =~ s/  +/ /g;
    next if $history{$lcname};
    $history{$lcname} = $name;
    for ( split " ", $lcname ){
	s/\W+$//;
	$histogram{$_}++;
	$total++;
    }
    $niteall_d_db->insert($lcname);
}
close($nite_all);

$niteall_d_db->close;
$niteall_e_db->close;

my $niteall_d_cs_db = simstring::reader->new($nitealldb_d_name);
$niteall_d_cs_db->swig_measure_set($simstring::cosine);
$niteall_d_cs_db->swig_threshold_set($cos_threshold);
my $niteall_e_cs_db = simstring::reader->new($nitealldb_e_name);
$niteall_e_cs_db->swig_measure_set($simstring::cosine);
$niteall_e_cs_db->swig_threshold_set($cos_threshold);


### input ###
if($suffix eq 'ttl'){
    use warnings;
    use RDF::Trine;
    use RDF::Query;

    my $model = RDF::Trine::Model->temporary_model;
    my $parser = RDF::Trine::Parser->new( 'turtle' );
    $parser->parse_file_into_model( $base_uri, $ta_query, $model );

    my $sparql =<<EOQ;
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix oa: <http://www.w3.org/ns/oa#>
prefix cnt: <http://www.w3.org/2011/content#>
prefix prov: <http://www.w3.org/ns/prov#>
prefix foaf: <http://xmlns.com/foaf/0.1/>
prefix gref: <http://genome.microbedb.jp/ontologies/genomerefine#>

SELECT 
 ?target ?content
FROM
 <http://genome.microbedb.jp/graph/annotation>
WHERE
{
?annotation oa:hasTarget ?target.
?annotation oa:hasBody ?body.
?body cnt:chars ?content.
}
EOQ

    my $query = RDF::Query->new( $sparql );
    my $iterator = $query->execute( $model );
    while (my $row = $iterator->next) {
         #$row->{ 'product' }->as_string ||= 'hypothetical protein';
    my $content = $row->{ 'content' }->as_string; 
    my $target  = $row->{ 'target' }->as_string;
    $content =~s/(^"|"$)//g; #Todo
    $content =~s/\n/ /g; #Todo
         &retrieve($content, $target);
         #print $row->{ 'id' }->as_string ."\t"  if ($opt_v);
    }
}else{
    use IO::File;
    use Text::CSV_XS;
    use Data::Dumper;

    my $fh = IO::File->new($ta_query) or die 'cannot open file: '.Text::CSV->error_diag ();
    my $csv = Text::CSV_XS->new({binary => 1});
    my $i =0;
    until ($fh->eof) {
        my $line = <$fh>;
        chomp($line);
        my @vals = split /\t/, $line;
        my $columns = \@vals;
        next if @$columns == 0;
        print join("\t",(@$columns))."\t" if ($opt_v and $opt_o ne 'ttl');
        my $query = $columns->[$entity_n];
        &retrieve($query,$columns->[$id_n]);
    }
    $fh->close;
}


$niteall_d_cs_db->close;
$niteall_e_cs_db->close;


sub retrieve {
    my $query = my $q = shift;
    my $id    = shift;
    my $match = my $result = my $info = '';
    $query ||= 'hypothetical protein';
    $query = lc($query);
    $query =~ s{[-/,]}{ }g;
    $query =~ s/  +/ /g;
    my $prfx = '';
    for ( @sp_words ){
        if(index($query, $_) == 0){
            $query =~ s/^$_\s+//;
	    $prfx = $_. ' ';
	    last;
        }
    }
    if($convtable{$query}){
	#print "ex\t", $prfx. $convtable{$query};
        $match ='ex';
        $result = $prfx. $convtable{$query};
    }else{
	my $retr = $niteall_d_cs_db->retrieve($query);
	my %qtms = map {$_ => 1} grep {s/\W+$//;$histogram{$_}} (split " ", $query);
	if($retr->[0]){
	    my ($minfreq, $minword, $ifhit) = getScore($retr, \%qtms, 1);
	    my %cache;
	    my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /} grep {$cache{$_}++; $cache{$_} == 1} @$retr;
	    my $le = (@out > $cs_max)?($cs_max-1):$#out;
	    #print "cs\t", join(" @@ ", (map {$prfx.$history{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
            $match = 'cs';
            $result = $prfx.$history{$out[0]};
            $info   = join(" @@ ", (map {$prfx.$history{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
	}else{
	    my $retr_e = $niteall_e_cs_db->retrieve($query);
	    if($retr_e->[0]){
		my ($minfreq, $minword, $ifhit) = getScore($retr_e, \%qtms, 0);
		my @hits = keys %$ifhit;
		my %cache;
		my @out = sort {$minfreq->{$a} <=> $minfreq->{$b} || $a =~ y/ / / <=> $b =~ y/ / /}
		          grep {$cache{$_}++; $cache{$_} == 1 && $minfreq->{$_} < $e_threashold} @hits;
		my $le = (@out > $cs_max)?($cs_max-1):$#out;
                $match = 'bcs';
                $result = defined $out[0]  ? $prfx.$convtable{$out[0]} : $q;
                $info   = join(" % ", (map {$prfx.$convtable{$_}.' ['.$minfreq->{$_}.':'.$minword->{$_}.']'} @out[0..$le]));
	    } else {
		#print "no_hit\t";
                $match  = 'no_hit';
                $result = $q;
	    }
	}
    }
    &output({'id'=> $id, 'query'=> $q, 'result' => $result, 'match' => $match, 'info' => $info});
}

sub output {
  my $h = shift @_;
  if($opt_o eq 'json'){
    print encode_json($h) ."\n";
  }elsif($opt_o eq 'ttl'){
    #default
    if ($opt_v and $opt_o eq 'ttl'){
        print '<'.$base_uri.'236/GR16/genes/'.$h->{'id'}. '#product   mdb:annotation [ rdfs:label  "'.$h->{'query'}.'" ;
    rdfs:comment    "generated by MiGAP" ;
    rdf:type mdb:AnnotationDeafualt ].'."\n"; 
    }
#if(0){
    #togoannotator
#    print $h->{'id'}. '    mdb:definition [ rdfs:label  "'.$h->{'result'}.'" ;
#    rdfs:comment    "'.$h->{'match'}.': generated by TogoAnnotator" ;
#    rdfs:comment    "'. $h->{'info'}.'" ;
#    rdf:type mdb:AnnotationAuto ; 
#    skos:prefLabel "'.$h->{'result'}.'" ]'."\n";

   my $uuid1 = $ug->create_str();
   my $uuid2 = $ug->create_str();
  my $dt = DateTime->now();
  my $date = $dt->datetime().'Z';
  #print Dumper $date;
print <<EOF;
<urn:uuid:$uuid1> a oa:Annotation;
    oa:hasTarget $h->{'id'};
    oa:hasBody  <urn:uuid:$uuid2> ; 
    oa:annotatedBy <http://dbcls.jp/togoannotator>.
    oa:annotatedAt "$date"^^xsd:dateTime ;
    oa:serializedBy <http://genome.annotation.jp/genomerefine>.
    oa:serializedAt "$date"^^xsd:dateTime ;

<urn:uuid:$uuid2> a cnt:ContentAsText ;
   a  gref:Annotated_gene_porduct ;
   cnt:chars "$h->{'result'}" ;
   skos:prefLabel "$h->{'result'}" ;
   skos:hiddenLabel "$h->{'query'}" ;
   rdfs:comment "$h->{'match'}" ;
   rdfs:comment "$h->{'info'}" ;
   cnt:characterEncoding "utf-8" . 

<http://dbcls.jp/togoannotator> a foaf:Agent, prov:SoftwareAgent ;
   foaf:name "TogoAnnotator".

<http://genome.annotation.jp/genomerefine> a foaf:Agent, prov:SoftwareAgent ;
   foaf:name "GenomeRefine".

EOF

    #ToDo: match ex,cs,bcs,no_hit とskos mapping
    #ToDo: togoannotatorの他の候補のaltLabel処理
#}
  }else{
    #print join("\t",($h->{'id'}, $h->{'query'},$h->{'result'},$h->{'match'},$h->{'info'}))."\n";
    print join("\t",($h->{'result'},$h->{'match'},$h->{'info'}))."\n";
  } 
}


sub getScore {
    my $retr = shift;
    my $qtms = shift;
    my $minf = shift;
    my (%minfreq, %minword, %ifhit);
    # 対象タンパク質のスコアは、当該タンパク質を構成する単語それぞれにつき、検索対象辞書中での当該単語の出現頻度のうち最小値を割り当てる
    # 最小値を持つ語は $minword{$_} に代入する
    # また、検索タンパク質名を構成する単語が、検索対象辞書からヒットした各タンパク質名に含まれている場合は $ifhit{$_} にフラグが立つ
    for (@$retr){
	my $score = 100000;
	my $word = '';
	my $hitflg = 0;
	for (split){
	    my $h = $histogram{$_} // 0;
	    if($qtms->{$_}){
		$hitflg++;
	    }else{
		$h += 10000;
	    }
	    if($score > $h){
		$score = $h;
		$word = $_;
	    }
	}
	$minfreq{$_} = $score;
	$minword{$_} = $word;
	$ifhit{$_}++ if $hitflg;
    }

    # 検索タンパク質名を構成する単語が、ヒットした各タンパク質名に複数含まれる場合には、その中で検索対象辞書中での出現頻度スコアが最小であるものを採用する
    # そして最小の語のスコアは-1とする。
    my $leastwrd = '';
    my $leastscr = 100000;
    for (keys %ifhit){
	if($minfreq{$_} < $leastscr){
	    $leastwrd = $_;
	    $leastscr = $minfreq{$_};
	}
    }
    if($minf && $leastwrd){
	for (keys %minword){
	    $minfreq{$_} = -1 if $minword{$_} eq $minword{$leastwrd};
	}
    }
    return (\%minfreq, \%minword, \%ifhit);
}

__END__

=head1 NAME

Protein Definition Normalizer

=head1 SYNOPSIS

normProt.pl -t0.7

=head1 ABSTRACT

配列相同性に基いて複数のプログラムにより自動的に命名されたタンパク質名の表記を、既に人手で正規化されている表記を利用して正規形に変換する。

=head1 COPYRIGHT AND LICENSE

Copyright by Yasunori Yamamoto / Database Center for Life Science
このプログラムはフリーであり、また、目的を問わず自由に再配布および修正可能です。

=cut