#!/opt/services/togoannot/local/perl-5.10.1/bin/perl

use warnings;
use strict;
use Fatal qw/open/;
use XML::XPath;
use XML::XPath::XMLParser;
use Text::Trim;
use PerlIO::gzip;

binmode STDOUT, ":utf8";

open(my $fh, "<:gzip", "enzyme-data.xml.gz");
my $xp = XML::XPath->new(ioref => $fh);
# my $xp = XML::XPath->new(filename => 'enzyme-data.xml');

my $nodeset = $xp->find('//table_data[@name="entry"]/row');
if (!$nodeset->isa('XML::XPath::NodeSet')) {
    print "Found $nodeset\n";
    exit;
}

foreach my $node ($nodeset->get_nodelist) {
    my $ecnumber = $xp->find('./field[@name="ec_num"]/text()', $node);
    my $ecnum = XML::XPath::XMLParser::as_string($ecnumber->pop);
    trim $ecnum;
    my $accepted = $xp->find('./field[@name="accepted_name"]/text()', $node);
    if(defined($accepted) && (my $p = $accepted->pop)){
	my $accepted_name = XML::XPath::XMLParser::as_string($p);
        trim $accepted_name;
        print $accepted_name, "\n" if $ecnum ne $accepted_name;
    }
    next;


    my $other_names = $xp->find('./field[@name="other_names"]/text()', $node);
    if(defined($other_names) && (my $p = $other_names->pop)){
	my @others = split /; /, XML::XPath::XMLParser::as_string($p);
	print join("\n", @others), "\n";
    }
}

close($fh);
__END__
