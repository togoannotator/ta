use Mojolicious::Lite;
use Mojo::Parameters;
use utf8;
use Encode qw/encode decode/;
use FindBin qw($Bin);
use lib "$Bin/..";
use Text::TogoAnnotator;

my $sysroot = "$Bin/..";
print "sysroot:", $sysroot, "\n";
our ($opt_t, $opt_m) = (0.6, 5);
Text::TogoAnnotator->init($opt_t, 30, $opt_m, 3, $sysroot, "dict_cyanobacteria_20151120_with_cyanobase.txt.gz","dict_cyanobacteria_curated.txt");
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
    return @queries;
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
    return @queries;
}

get '/' => sub {
    shift->render(title => 'Search page');
} => 'index';

get '/annotate/gene/:definition' => sub {
    my $self = shift;

    my $defs = $self->param('definition');
    Text::TogoAnnotator->openDicts;
    my $r = Text::TogoAnnotator->retrieve($defs);
    Text::TogoAnnotator->closeDicts;

    return $self->render(json => $r);
};

post '/annotate/genes' => sub {
    my $self = shift;

    my $upload = $self->param('upload');
    if (ref $upload eq 'Mojo::Upload') {

	my $file_type = $upload->headers->content_type;
	#my %valid_types = map {$_ => 1} qw(image/gif image/jpeg image/png);

	my @queries = file2queries($upload->slurp);
	my @out = ();
	foreach my $q (@queries){
	    my $r = Text::TogoAnnotator->retrieve($q);
	    push @out, $r;
	}
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

	my @queries = ddbjfile2queries($upload->slurp);
	my @out = ();
	foreach my $q (@queries){
	    my $r = Text::TogoAnnotator->retrieve($q);
	    push @out, $r;
	}
	return $self->render(json => @out);

    }else{
	$self->redirect_to('index');
    }
};

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

    <title>Starter Template for Bootstrap</title>

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
  </head>
  <body>
    <%= content %>

    <!-- Bootstrap core JavaScript
    ================================================== -->
    <!-- Placed at the end of the document so the pages load faster -->
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.4/jquery.min.js"></script>
    <script>window.jQuery || document.write('<script src="/js/jquery.min.js"><\/script>')</script>
    <script src="/js/bootstrap.min.js"></script>
    <!-- IE10 viewport hack for Surface/desktop Windows 8 bug -->
    <script src="/js/ie10-viewport-bug-workaround.js"></script>
  </body>
</html>

@@ index.html.ep
% layout 'default';
 <h1>TogoAnnotator</h1>
