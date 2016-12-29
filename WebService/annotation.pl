use Mojolicious::Lite;
use Mojo::Parameters;
use utf8;
use Encode qw/encode decode/;
use FindBin qw($Bin);
use lib "$Bin/..";
use Text::TogoAnnotator;
use Data::Dumper;

app->config(hypnotoad => {listen => ['http://*:5000']});
#app->mode('production');
app->mode('development');

#plugin 'PODRenderer';
plugin 'CORS';

my $sysroot = "$Bin/..";
print "sysroot:", $sysroot, "\n";
our ($opt_t, $opt_m) = (0.6, 5);
#Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120_with_cyanobase.txt.gz","dict_cyanobacteria_curated.txt");
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
        //url = "http://petstore.swagger.io/v2/swagger.json";
        url = "/swagger.json";
        //url = "http://togo.genes.nig.ac.jp:3000//swagger.json";
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
        docExpansion: "none",
        jsonEditor: false,
        defaultModelRendering: 'schema',
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
  </head>
  <body>
<!--// swagger UI begin -->
<body class="swagger-section">
   <div class="jumbotron text-center">
      <img style="width: 600px; height: 240 px;" src="images/horizontal.png" alt="TogoAnnotator" title="TogoAnnotator">
      <!--//<h1>TogoAnnotator</h1>-->
      <p>A tool for genome reannotation</p>
   </div> 
<!--//   
<div id='header'>
  <div class="swagger-ui-wrap">
    <a id="logo" href="http://swagger.io"><img class="logo__img" alt="swagger" height="30" width="30" src="images/logo_small.png" /><span class="logo__title">swagger</span></a>
    <form id='api_selector'>
      <div class='input'><input placeholder="http://example.com/api" id="input_baseUrl" name="baseUrl" type="text"/></div>
      <div id='auth_container'></div>
      <div class='input'><a id="explore" class="header__btn" href="#" data-sw-translate>Explore</a></div>
    </form>
  </div>
</div>
-->

<div id="message-bar" class="swagger-ui-wrap" data-sw-translate>&nbsp;</div>
<div id="swagger-ui-container" class="swagger-ui-wrap"></div>
<!--//swagger UI end -->

    <%= content %>

    <!-- Bootstrap core JavaScript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <!--<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.4/jquery.min.js"></script>-->
    <!--<script>window.jQuery || document.write('<script src="/js/jquery.min.js"><\/script>')</script>-->
    <script src="/js/bootstrap.min.js"></script>
    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/js/ie10-viewport-bug-workaround.js"></script>
    <div class="jumbotron text-center">

    <p>
     <a rel="license" href="http://creativecommons.org/licenses/by/2.1/jp/">
     <img alt="Creative Commons License" style="border-width:0" src="http://i.creativecommons.org/l/by/2.1/jp/88x31.png" /></a>
       <a xmlns:dc="http://purl.org/dc/elements/1.1/" href="http://purl.org/dc/dcmitype/Text" rel="dc:type" style="text-decoration:none;color:black">TogoAnnotator</a> by <a xmlns:cc="http://creativecommons.org/ns#" href="http://dbcls.rois.ac.jp/" rel="cc:attributionURL">Database Center for Life Science (DBCLS)</a> is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/2.1/jp/">Creative Commons &#34920;&#31034; 2.1 &#26085;&#26412; License</a>. This software includes the work that is distributed in the Apache License 2.0.
    </p>
    <!--//<p> &copy; Copyright 2016-2017 <a href="http://dbcls.rois.ac.jp/">DBCLS</a></p>-->
    </div>
  </body>
</html>

@@ index.html.ep
% layout 'default';
%= content;

