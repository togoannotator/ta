use Mojolicious::Lite;
use Mojo::Parameters;
use Mojo::Server::Prefork;
use utf8;
use Encode qw/encode decode/;
use FindBin qw($Bin);
use lib "$Bin/..";
use Text::TogoAnnotatorES;
use Data::Dumper;

plugin 'CORS';

my $config = plugin 'JSONConfig';
my $port = 5001;
#my $config_dict = $config->{'DDBJCurated'};
my $config_dict = $config->{'UniProtLeeModified'};
#print Dumper $config;
my $dicts = {};
while (my ($k, $v) = each(%$config)){
  $dicts->{$v->{'namespace'}} = $k; 
}
#print Dumper $dicts;

$ENV{'TA_ENV'} ||= 'production';
app->config(hypnotoad => {listen => ['http://*:'.$port], heartbeat_timeout => 1200, pid_file => './hypnotoad'. $port.'.pid'});
app->mode($ENV{'TA_ENV'});

my $sysroot = "$Bin/..";
$config_dict->{'sysroot'} = $sysroot;

#print "### Server settings\n";
while (my($k, $v) =  each %$config_dict){
  printf("%- 14s %s\n","$k:", $v);
}
print "\n";

Text::TogoAnnotatorES->init($sysroot);

print "Server ready.\n";

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
   $self->render(template => 'index');
};

get '/api' => sub {
  my $self = shift;
  $self->render(template => 'index');
};

app->types->type(jsonld => 'application/ld+json');

app->helper(
  retrieve => sub {
    my ($self, $defs, $dict_ns, $opts) = @_;
    my $r = Text::TogoAnnotatorES->retrieve($defs, $dicts->{$dict_ns}, $opts);
    return $r;
  });

app->helper(
  retrieve_array => sub {
    my ($self, $queries, $dict_ns, $opts) = @_;
    return Text::TogoAnnotatorES->retrieveMulti($queries, $dicts->{$dict_ns}, $opts);
  }
);

get '/gene' => sub {
    my $self = shift;
    my $defs = $self->param('query');
    my $dict_ns = $self->param('dictionary');
    my $opts = {};
    foreach my $p (qw(max_query_terms minimum_should_match min_term_freq min_word_length max_word_length)){
      my $pp = uc $p;
      $opts->{$pp} = $self->param($p) if $self->param($p) ; 
    };
    $opts->{'HITS'} = $self->param('limit') if  $self->param('limit') ;
    #print Dumper $opts;
    my $r = $self->retrieve($defs, $dict_ns, $opts);
    return $self->render(json => $r);
    #$self->stash(record => $r);
    #$self->respond_to(
    #  json => {json => $r},
    #);
};

get '/genes' => sub {
    my $self = shift;
    my @defs = $self->every_param('query');
    my $dict_ns = $self->param('dictionary');
    my $opts ={};
    foreach my $p (qw(max_query_terms minimum_should_match min_term_freq min_word_length max_word_length)){
      my $pp = uc $p;
      $opts->{$pp} = $self->param($p) if $self->param($p) ;
    };
    $opts->{'HITS'} = $self->param('limit') if  $self->param('limit') ;
    my $r = $self->retrieve_array(@defs, $dict_ns, $opts);
    #my $r = $self->retrieve_array(@defs, $dict_ns, $opts);
    return $self->render(json => $r);
};

post '/genes' => sub {
    my $self = shift;
    my $upload = $self->param('upload');
    my $dict_ns = $self->param('dictionary');
    my $opts ={};
    foreach my $p (qw(max_query_terms minimum_should_match min_term_freq min_word_length max_word_length)){
      my $pp = uc $p;
      $opts->{$pp} = $self->param($p) if $self->param($p) ;
    };
    $opts->{'HITS'} = $self->param('limit') if  $self->param('limit') ;
    if (ref $upload eq 'Mojo::Upload') {
        my $file_type = $upload->headers->content_type;
        my $queries = file2queries($upload->slurp);
        my @out = $self->retrieve_array($queries, $dict_ns, $opts);
	return $self->render(json => \@out);
    }else{
        return $self->render(json => {});
        #$self->redirect_to('index');
    }
};

post '/ddbj' => sub {
    my $self = shift;
    my $upload = $self->param('upload');
    my $dict_ns = $self->param('dictionary');
    if (ref $upload eq 'Mojo::Upload') {
	my $file_type = $upload->headers->content_type;
	my $queries = ddbjfile2queries($upload->slurp);
        my @out = $self->retrieve_array($queries, $dict_ns);
	return $self->render(json => \@out);
    }else{
	$self->redirect_to('index');
    }
};

app->log->level('debug');
app->start;

__DATA__

@@ layouts/default.html.ep
<!-- HTML for static distribution bundle build -->
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>TogoAnnotator</title>
    <script type="text/javascript" src="https://dbcls.rois.ac.jp/DBCLS-common-header-footer/common-header-and-footer/script/common-header-and-footer.js" id="common-header-and-footer__script"></script>
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">
    <script src="https://code.jquery.com/jquery-3.3.1.slim.min.js" integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo" crossorigin="anonymous"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.7/umd/popper.min.js" integrity="sha384-UO2eT0CpHqdSJQ6hJty5KVphtPhzWj9WO1clHTMGa3JDZwrnQq4sF86dIHNDz0W1" crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js" integrity="sha384-JjSmVgyd0p3pXB1rRibZUAYoIIy6OrQ6VrjIEaFf/nJGzIxFDsf4x0xIM+B07jRM" crossorigin="anonymous"></script>
    <link rel="stylesheet" type="text/css" href="/dist/swagger-ui.css" >
    <link rel="icon" type="image/png" href="images/favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="images/favicon-16x16.png" sizes="16x16" />
    <link rel="icon" type="image/png" href="images/favicon-96x96.png" sizes="96x96" />
    <style>
      html
      {
        box-sizing: border-box;
        overflow: -moz-scrollbars-vertical;
        overflow-y: scroll;
      }

      *,
      *:before,
      *:after
      {
        box-sizing: inherit;
      }

      body
      {
        margin:0;
        background: #fafafa;
      }

.col { 
  width: auto;
}

    </style>
  </head>

  <body>
    <div id="home" class="container px-lg-5">
      <div class="row align-items-center mt-3 mx-lg-5">
        <img src="images/horizontal.png" class="img-fluid px-lg-5" alt="TogoAnnotator">
<ul class="nav nav-pills nav-justified">
  <li class="nav-item"><a href="#" class="nav-link active">Home</a></li>
  <li class="nav-item"><a href="https://docs.json2ld.mapper.tokyo" class="nav-link disabled" tabindex="-1" aria-disabled="true">Documents</a></li>
</ul>
      </div>
      <div class="row align-items-center mt-3 mx-lg-5">
        <div class="h2">What is TogoAnnotator?</div>
      </div>
      <div class="row align-items-center mt-3 mx-lg-5">
        <p>This tool normalizes gene product names and assists with the curation task.</p>
      </div>
    </div>
    <div class="hr">

    <div id="swagger-ui"></div>

    <script src="/dist/swagger-ui-bundle.js"> </script>
    <script src="/dist/swagger-ui-standalone-preset.js"> </script>
    <script>
    window.onload = function() {
      // Begin Swagger UI call region
      const ui = SwaggerUIBundle({
        //url: "/v1/2/swagger.json",
        url: "/v2/0/openapi.json",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIStandalonePreset
        ],
        plugins: [
          SwaggerUIBundle.plugins.DownloadUrl
        ],
        layout: "StandaloneLayout"
      })
      // End Swagger UI call region

      window.ui = ui
    }
  </script>
  </body>
</html>

@@ index.html.ep
% layout 'default';
%= content;

