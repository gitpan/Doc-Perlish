#  -*- perl -*-
#
# Tests building documents in one step
#

use Test::More tests => 4;
use Storable qw(nstore);

BEGIN {
    use_ok("Doc::Perlish");
}

# isn't this ironic - after that rant in Doc::Perlish::Parser::XML, here am
# I faced with the fact that it was in fact extremely easy to make a
# parser for it.  In the words of autrijus, "it parses itself".
my $doc = Doc::Perlish->new( type => "XML", input => "t/data/test.xml" );
isa_ok($doc, "Doc::Perlish", "Perldoc->new");

# ah, you might be saying - but what state is the above it, shouldn't
# it have been a constructor on Doc::Perlish::DOM?

# well, it isn't actually a DOM yet.  It's a Doc::Perlish document.  such
# an entity doesn't even have a form or a state, but that doesn't
# matter, because you can easily get a dom tree out of it;

my $dom = $doc->to_dom;

# perhaps it was not until you did that that Doc::Perlish actually cranked
# up its reader.  I guess you'll never know, unless you read the
# source.  But who cares, anyway?  :)
isa_ok($dom, "Doc::Perlish::DOM", "Perldoc->dom");

isa_ok($doc->root, "Doc::Perlish::DOM::Node", "Perldoc->root");


