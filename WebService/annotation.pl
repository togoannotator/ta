use Mojolicious::Lite;
use Mojo::Parameters;
use Mojo::Server::Prefork;
use utf8;
use Encode qw/encode decode/;
use FindBin qw($Bin);
use lib "$Bin/..";
use Text::TogoAnnotator;
use Data::Dumper;
use Mojo::mysql;

#my $port = $ENV{HYP_PORT} // 5001;
my $config = plugin 'JSONConfig';

#$ENV{'TA_DICT_NO'}
#$ENV{'TA_DICT_NAME'}
$ENV{'TA_ENV'} ||= 'production';
my @dicts =  sort {$config->{$a}->{'port'} <=> $config->{$b}->{'port'}} grep { !/_default/ } keys %$config;
my $dict = '';
if(my $no = $ENV{'TA_DICT_NO'}){
  $dict = $dicts[$no];
}elsif($ENV{'TA_DICT_NAME'}){
  $dict = $ENV{'TA_DICT_NAME'};
}else{
  #$dict = '_default'; #$dicts[0]; 
}

print "### Environment variables\n"; 
print 'TA_ENV: ',$ENV{'TA_ENV'},"\n";
print 'TA_DICT_NO: ', $ENV{'TA_DICT_NO'} ||'' ,"\n";
print 'TA_DICT_NAME: ', $ENV{'TA_DICT_NAME'} ||'',"\n";
print "\n";

unless ($config->{$dict}){
  warn "The server can be run with one of the following commands.\n";
  while ( my( $no, $name ) = each @dicts ) {
    warn "[$no] $name: export TA_DICT_NO=$no;hypnotoad ./annotation.pl\" or \"export TA_DICT_NAME=$name;hypnotoad ./annotation.pl\"\n";      
  }
  exit;
}

my $config_dict = $config->{$dict};
app->config(hypnotoad => {listen => ['http://*:'.$config_dict->{'port'}], heartbeat_timeout => 1200, pid_file => './hypnotoad'. $config_dict->{'port'}.'.pid'});
#app->config(hypnotoad => {listen => ['http://*:'.$config_dict->{'port'}], heartbeat_timeout => 1200});
app->mode($ENV{'TA_ENV'});

my $sysroot = "$Bin/..";
$config_dict->{'sysroot'} = $sysroot;
print "### Server settings\n";
while (my($k, $v) =  each %$config_dict){
  printf("%- 14s %s\n","$k:", $v);
}
print "\n";

#plugin 'PODRenderer';
plugin 'CORS';
#plugin 'JSONConfig';

our ($opt_t, $opt_m) = ($config_dict->{'cos_threshold'}, $config_dict->{'cs_max'});
Text::TogoAnnotator->init($opt_t, $config_dict->{'e_threashold'}, $opt_m, $config_dict->{'n_gram'}, $sysroot, $config_dict->{'niteAll'}, $config_dict->{'curatedDict'}, 1);

print "\n";
print "### Server\n";
print "Server ready.\n";

# sub match{
#   my @queries = @_;
#   my @out = ();
#   foreach my $q (@queries){
#     my $r = Text::TogoAnnotator->retrieve($q);
#     my $json = JSON::XS->new->utf8(0)->encode($r);
#     push @out, $json;
#   }
#   return "[".join(",",@out)."]";
# }

=head
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
=cut

=head
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
=cut
sub file2queries {
    my @queries = ();

    return unless $_[0];
    for (split /[\r\n]/, $_[0]){
	next if /^#/;
	push @queries, $_;
    }
    return \@queries;
}

sub ddbjfile2queries {
    my @queries = ();

    return unless $_[0];
    for (split /[\r\n]/, $_[0]){
	my @a = split "\t";
	if($a[3] eq 'product'){
	    push @queries, $a[4];
	}
    }
    # print join("\n", @queries), "\n";
    return \@queries;
}

sub bioseqio2queries {
    my @queries = ();
    return unless $_[0];
    use Bio::SeqIO;
    use IO::String;
    my $stringio = IO::String->new($_[0]);
    my $seqio_object = Bio::SeqIO->new(-fh => $stringio, -format => 'genbank');
    #my $seqio_object = Bio::SeqIO->new(-file => $_[0], -format => 'genbank');
    my $seq_object = $seqio_object->next_seq;
    for my $feat_object ($seq_object->get_SeqFeatures) {
      #print "primary tag: ", $feat_object->primary_tag, "\n";
        for my $tag ($feat_object->get_all_tags) {
            #print "  tag: ", $tag, "\n";
            next if $tag ne 'product';
            for my $value ($feat_object->get_tag_values($tag)) {
                #print "    value: ", $value, "\n";
                push @queries, $value;
            }
        }
    }
    return \@queries;
}

sub fasta2queries {
    my @queries = ();
    return unless $_[0];
    use Bio::SeqIO;
    use IO::String;
    my $stringio = IO::String->new($_[0]);
    my $seqio_object = Bio::SeqIO->new(-fh => $stringio, -format => 'fasta');
    while (my $seq = $seqio_object->next_seq) {
        #print Dumper $seq->desc;
        push @queries, $seq->desc;
    }    
    return \@queries;
}

sub biosearchio2queries {
   my @queries = ();
   return unless $_[0];
   use Bio::SearchIO;
   use IO::String;
   my $stringio = IO::String->new($_[0]);
   my $report_obj = new Bio::SearchIO( -fh => $stringio, -format => 'blast');
    while( my $result = $report_obj->next_result ) {
        while( my $hit = $result->next_hit ) {
          (my $f = $hit->description) =~ s/[[:cntrl:]].*$//;
	  $f =~ s/ *\[[^\[\]]+\]$//; # 末尾が]で終わっているときは、そこに生物種名が含まれているという想定の下、その部分を除去。
          push @queries, $f;
          #push @queries, trim( substr($f, 0, rindex($f, "[")) );
            #while( $hsp = $hit->next_hsp ) {
            #        $hsp->percent_identity, "\n";
            #}
         }
    }
    return \@queries;
}

sub gff2queries {
   my @queries = ();
   return unless $_[0];
   use Bio::Tools::GFF;
   use IO::String;
   my $stringio = IO::String->new($_[0]);
   #my $gff_filename = shift;
   #my $gffio = Bio::Tools::GFF->new( -file => $gff_filename, -gff_version => 3 );
   my $gffio = Bio::Tools::GFF->new( -fh => $stringio, -gff_version => 3 );

   while ( my $feature = $gffio->next_feature() ) { 
      for my $tag ($feature->get_all_tags) {
        #print "  tag: ", $tag, "\n";
         next if $tag ne 'product';
         for my $value ($feature->get_tag_values($tag)) {
           #print "    value: ", $value, "\n";
            push @queries, $value;
         }   
      }   
   }
   $gffio->close();
   return \@queries;
}

get '/' => sub {
   my $self = shift;
   #$self->stash(name => qq{TogoAnnotator});
   $self->render(template => 'index');
};


#post '/annotate' => sub {
#    my $self = shift;
#    my $o = $self->openapi->valid_input or return;
#    my $data = { body => $o->validation->param("body")};
#    my $html = $o->render(openapi => $data);
#    $self->stash( apidoc=> $html);
#    #$self->render(template => 'apidoc');
#};

get '/annotate/gene/*definition' => sub {
    my $self = shift;

    my $defs = $self->param('definition');
    Text::TogoAnnotator->openDicts;
    my $r = Text::TogoAnnotator->retrieve($defs);
    Text::TogoAnnotator->closeDicts;

   #return $self->render(json => $r);
   $self->respond_to(
     json => {json => $r},
     html => sub {$self->render(json => $r)},
     #html => {template => 'gene', message => 'world'},
     any  => {text => 'Invalid format. Available formats are json or html.', status => 204}
   );
};

post '/annotate/genes' => sub {
    my $self = shift;

    my $upload = $self->param('upload');
    if (ref $upload eq 'Mojo::Upload') {

	my $file_type = $upload->headers->content_type;
	#my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

	Text::TogoAnnotator->openDicts;
	my $queries = file2queries($upload->slurp);
	my @out = ();
	foreach my $q (@$queries){
	    my $r = Text::TogoAnnotator->retrieve($q);
	    push @out, $r;
	}
	Text::TogoAnnotator->closeDicts;
	return $self->render(json => \@out);

    }else{
      $self->redirect_to('index');
    }
};

post '/annotate/ddbj' => sub {
    my $self = shift;

    my $upload = $self->param('upload');
    if (ref $upload eq 'Mojo::Upload') {

	my $file_type = $upload->headers->content_type;
	#my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

	Text::TogoAnnotator->openDicts;
	my $queries = ddbjfile2queries($upload->slurp);
	my @out = ();
	foreach my $q (@$queries){
	    my $r = Text::TogoAnnotator->retrieve($q);
	    push @out, $r;
	}
	Text::TogoAnnotator->closeDicts;
	return $self->render(json => \@out);

    }else{
	$self->redirect_to('index');
    }
};

post '/annotate/genbank' => sub {
    my $self = shift;

    my $upload = $self->param('upload');
    if (ref $upload eq 'Mojo::Upload') {

  my $file_type = $upload->headers->content_type;
  #my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

  Text::TogoAnnotator->openDicts;
  my $queries = bioseqio2queries($upload->slurp);
  #my $queries = bioseqio2queries($upload->filename);
  my @out = ();
  foreach my $q (@$queries){
      my $r = Text::TogoAnnotator->retrieve($q);
      push @out, $r;
  }
  Text::TogoAnnotator->closeDicts;
  return $self->render(json => \@out);

    }else{
  $self->redirect_to('index');
    }
};

post '/annotate/fasta' => sub {
    my $self = shift;

    my $upload = $self->param('upload');
    if (ref $upload eq 'Mojo::Upload') {

  my $file_type = $upload->headers->content_type;
  #my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

  Text::TogoAnnotator->openDicts;
  my $queries = fasta2queries($upload->slurp);
  my @out = ();
  foreach my $q (@$queries){
      my $r = Text::TogoAnnotator->retrieve($q);
      push @out, $r;
  }
  Text::TogoAnnotator->closeDicts;
  return $self->render(json => \@out);

    }else{
  $self->redirect_to('index');
    }
};


post '/annotate/blast' => sub {
   my $self = shift;

   my $upload = $self->param('upload');
   if (ref $upload eq 'Mojo::Upload') {

  my $file_type = $upload->headers->content_type;
  #my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

  Text::TogoAnnotator->openDicts;
  my $queries = biosearchio2queries($upload->slurp);
  #my $queries = bioseqio2queries($upload->filename);
  my @out = ();
  foreach my $q (@$queries){
      my $r = Text::TogoAnnotator->retrieve($q);
      push @out, $r;
  }
  Text::TogoAnnotator->closeDicts;
  return $self->render(json => \@out);

    }else{
  $self->redirect_to('index');
    }
};

post '/annotate/gff' => sub {
   my $self = shift;

   my $upload = $self->param('upload');
   if (ref $upload eq 'Mojo::Upload') {

  my $file_type = $upload->headers->content_type;
  #my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

  Text::TogoAnnotator->openDicts;
  my $queries = gff2queries($upload->slurp);
  #my $queries = bioseqio2queries($upload->filename);
  my @out = ();
  foreach my $q (@$queries){
      my $r = Text::TogoAnnotator->retrieve($q);
      push @out, $r;
  }
  Text::TogoAnnotator->closeDicts;
  return $self->render(json => \@out);

    }else{
  $self->redirect_to('index');
    }
};


#plugin OpenAPI => {url => app->home->rel_file("public/swagger.json")};
app->log->level('debug');
app->start;

__DATA__

@@ layouts/default.html.ep
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
    <meta name="description" content="">
    <meta name="author" content="">
    <!-- <link rel="icon" href="../../favicon.ico"> -->
    <title>TogoAnnotator</title>

  <!--//swagger UI begin -->
  <link rel="icon" type="image/png" href="images/favicon-32x32.png" sizes="32x32" />
  <link rel="icon" type="image/png" href="images/favicon-16x16.png" sizes="16x16" />
  <link href='css/typography.css' media='screen' rel='stylesheet' type='text/css'/>
  <link href='css/reset.css' media='screen' rel='stylesheet' type='text/css'/>
  <link href='css/screen.css' media='screen' rel='stylesheet' type='text/css'/>
  <link href='css/reset.css' media='print' rel='stylesheet' type='text/css'/>
  <link href='css/print.css' media='print' rel='stylesheet' type='text/css'/>

  <script src='lib/object-assign-pollyfill.js' type='text/javascript'></script>
  <script src='lib/jquery-1.8.0.min.js' type='text/javascript'></script>
  <script src='lib/jquery.slideto.min.js' type='text/javascript'></script>
  <script src='lib/jquery.wiggle.min.js' type='text/javascript'></script>
  <script src='lib/jquery.ba-bbq.min.js' type='text/javascript'></script>
  <script src='lib/handlebars-4.0.5.js' type='text/javascript'></script>
  <script src='lib/lodash.min.js' type='text/javascript'></script>
  <script src='lib/backbone-min.js' type='text/javascript'></script>
  <script src='swagger-ui.js' type='text/javascript'></script>
  <script src='lib/highlight.9.1.0.pack.js' type='text/javascript'></script>
  <script src='lib/highlight.9.1.0.pack_extended.js' type='text/javascript'></script>
  <script src='lib/jsoneditor.min.js' type='text/javascript'></script>
  <script src='lib/marked.js' type='text/javascript'></script>
  <script src='lib/swagger-oauth.js' type='text/javascript'></script>

  <!-- Some basic translations -->
  <!-- <script src='lang/translator.js' type='text/javascript'></script> -->
  <!-- <script src='lang/ru.js' type='text/javascript'></script> -->
  <!-- <script src='lang/en.js' type='text/javascript'></script> -->

  <script type="text/javascript">
    $(function () {
      var url = window.location.search.match(/url=([^&]+)/);
      if (url && url.length > 1) {
        url = decodeURIComponent(url[1]);
      } else {
        url = "/v1/1/swagger.json";
      }

      hljs.configure({
        highlightSizeThreshold: 5000
      });

      // Pre load translate...
      if(window.SwaggerTranslator) {
        window.SwaggerTranslator.translate();
      }
      window.swaggerUi = new SwaggerUi({
        url: url,
        dom_id: "swagger-ui-container",
        supportedSubmitMethods: ['get', 'post', 'put', 'delete', 'patch'],
        onComplete: function(swaggerApi, swaggerUi){
          if(typeof initOAuth == "function") {
            initOAuth({
              clientId: "your-client-id",
              clientSecret: "your-client-secret-if-required",
              realm: "your-realms",
              appName: "your-app-name",
              scopeSeparator: " ",
              additionalQueryStringParams: {}
            });
          }

          if(window.SwaggerTranslator) {
            window.SwaggerTranslator.translate();
          }
        },
        onFailure: function(data) {
          log("Unable to Load SwaggerUI");
        },
        docExpansion: "full",
        jsonEditor: false,
        //defaultModelRendering: 'schema',
        defaultModelRendering: 'model',
        showRequestHeaders: false
      });

      window.swaggerUi.load();

      function log() {
        if ('console' in window) {
          console.log.apply(console, arguments);
        }
      }
  });
  </script><!--//swagger UI end-->

    <!-- Bootstrap core CSS -->
    <link href="/css/bootstrap.min.css" rel="stylesheet">

    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <link href="/css/ie10-viewport-bug-workaround.css" rel="stylesheet">

    <!-- Custom styles for this template -->
    <!-- <link href="starter-template.css" rel="stylesheet"> -->

    <!-- Just for debugging purposes. Don't actually copy these 2 lines! -->
    <!--[if lt IE 9]><script src="../../assets/js/ie8-responsive-file-warning.js"></script><![endif]-->
    <script src="/js/ie-emulation-modes-warning.js"></script>

    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.3/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->

    <!-- for mojo/debug
    <script src="/mojo/jquery/jquery.js"></script>
    <script src="/mojo/prettify/run_prettify.js"></script>
    <link href="/mojo/prettify/prettify-mojo-dark.css" rel="stylesheet">
    -->
<style type="text/css">
body { padding-top: 40px; }
 @media screen and (max-width: 768px) {
    body { padding-top: 0px; }
    }

.container {
  max-width: 880px !important;
  margin-left: auto !important;
  margin-right: auto !important;
}

</style>
</head>
<body>
<!--//<div class="jumbotron">-->
  <div class="text-center">
  <nav class="navbar navbar-inverse navbar-fixed-top">
    <div class="container">
      <div class="navbar-header">
        <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="false" aria-controls="navbar">
          <span class="sr-only">Toggle navigation</span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
        </button>
        <a class="navbar-brand" href="#">TogoAnnotator</a>
      </div>
      <div id="navbar" class="collapse navbar-collapse">
        <ul class="nav navbar-nav">
          <li class="active"><a href="#">Home</a></li>
          <li><a href="/help.html">Help</a></li>
        </ul>
      </div>
    </div>
  </nav>
  </div>

  <div class="page-header text-center">
    <!--//<div class="swagger-ui-wrap text-center">-->
      <img style="width: 600px; height: 240 px;" src="images/horizontal.png" alt="TogoAnnotator" title="TogoAnnotator">
      <p>A tool for genome reannotation</p>
    <!--//</div>-->
  </div>
  
  <div>
    <div class="swagger-section">
      <div id="message-bar" class="swagger-ui-wrap" data-sw-translate>&nbsp;</div>
      <div id="swagger-ui-container" class="swagger-ui-wrap"></div>
      <!--//swagger UI end -->

      <!--//API Sample -->      
      <div id="swagger-ui-container" class="swagger-ui-wrap">
        <div class="info" id="api_sample">
          <div class="info_title">API request examples</div>
            <h2>1. Input "DnaA" query</h2>
<pre class="prettyprint">
#!sh
$ curl -s 'http://togoannotator.dbcls.jp/annotate/gene/DnaA' | jq
</pre>

            <h2>2. Input <a href="/annotation_list.txt">annotation_list.txt</a></h2>
<pre class="prettyprint">
#!sh
$ curl -s http://togoannotator.dbcls.jp/annotation_list.txt | curl -s -F 'upload=@-' 'http://togoannotator.dbcls.jp/annotate/genes' | jq

</pre>

            <h2>3. Input <a href="/ddbj_submission.txt">ddbj_submission.txt</a></h2>
<pre class="prettyprint">
#!sh
$ curl -s http://togoannotator.dbcls.jp/ddbj_submission.txt | curl -s -F 'upload=@-' 'http://togoannotator.dbcls.jp/annotate/ddbj' | jq

</pre>

            <h2>4. Input GenBank format file <a href="http://togows.dbcls.jp/entry/nucleotide/BA000022.gb">BA000022.gb</a></h2>
<pre class="prettyprint">
#!sh
$ curl -s http://togows.dbcls.jp/entry/nucleotide/BA000022.gb | curl -s -F 'upload=@-' 'http://togoannotator.dbcls.jp/annotate/genbank'  |jq

</pre>

            <h2>5. Input BLAST report file <a href="/7XS7A95B015-Alignment.txt">7XS7A95B015-Alignment.txt</a></h2>
<pre class="prettyprint">
#!sh
$ curl -s http://togoannotator.dbcls.jp/7XS7A95B015-Alignment.txt | curl -s -F 'upload=@-' 'http://togoannotator.dbcls.jp/annotate/blast'  |jq

</pre>

            <h2>6. Input GFF3 format file <a href="http://togows.dbcls.jp/entry/nucleotide/BA000022.gff">BA000022.gff</a></h2>
<pre class="prettyprint">
#!sh
$ curl -s http://togows.dbcls.jp/entry/nucleotide/BA000022.gff | curl -s -F 'upload=@-' 'http://togoannotator.dbcls.jp/annotate/gff'
</pre>

            <h2>7. Input FASTA format file <a href="http://togows.dbcls.jp/entry/nucleotide/ABA25090.1.fasta">ABA25090.1.fasta</a></h2>
<pre class="prettyprint">
#!sh
$ curl -s http://togows.dbcls.jp/entry/nucleotide/ABA25090.1.fasta | curl -s -F 'upload=@-' 'http://togoannotator.dbcls.jp/annotate/fasta'   |jq
</pre>


          </div>
        </div>
      </div>
    </div>
  </div>  
<!--//</div>-->  
    <%= content %>
<!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
<script src="/js/ie10-viewport-bug-workaround.js"></script>

<!--// TogoAnnotator Footer-->
<div class="jumbotron text-center">
  <p>
    <a rel="license" href="http://creativecommons.org/licenses/by/2.1/jp/">
    <img alt="Creative Commons License" style="border-width:0" src="/images/by.png" width="88" height="31" /></a>
    <a xmlns:dc="http://purl.org/dc/elements/1.1/" href="http://purl.org/dc/dcmitype/Text" rel="dc:type" style="text-decoration:none;color:black">TogoAnnotator</a> by <a xmlns:cc="http://creativecommons.org/ns#" href="http://dbcls.rois.ac.jp/" rel="cc:attributionURL">Database Center for Life Science (DBCLS)</a> is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/2.1/jp/">Creative Commons &#34920;&#31034; 2.1 &#26085;&#26412; License</a>.
  </p>
  <p>This software includes the work that is distributed in the Apache License 2.0.</p>
</div>

</body>
</html>

@@ index.html.ep
% layout 'default';
%= content;
