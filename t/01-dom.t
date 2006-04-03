#  -*- perl -*-

use strict;
use Test::More tests => 13;
use Storable qw(nstore dclone);

use_ok("Doc::Perlish::DOM::Node");
eval { Doc::Perlish::DOM::Node->new(); };
like($@, qr/attempt/, "Doc::Perlish::DOM::Node->new() - dies correctly");

use_ok("Doc::Perlish::DOM::Element");
#$Tree::DAG_Node::DEBUG = 1;
my $node = Doc::Perlish::DOM::Element->new
    ({ name => "sect1",
       source => "=head1 ",  # text "eaten" by this node
     });
isa_ok($node, "Doc::Perlish::DOM::Node", "->new()");
is($node->source, "=head1 ", "->source() (::Element)");
is($node->name, "sect1", "->name() (::Element)");

my $title = Doc::Perlish::DOM::Element->new ({ name => "title" });
$node->add_daughter($title);

use_ok("Doc::Perlish::DOM::Text");
my $text = Doc::Perlish::DOM::Text->new ("NAME");
is($text->source, "NAME", "->source() (::Text)");
is($text->content, "NAME", "->content() (::Text)");

$title->add_daughter($text);

use_ok("Doc::Perlish::DOM");

my $kwom = Doc::Perlish::DOM->new();
isa_ok($kwom, "Doc::Perlish::DOM", "new DOM");

$kwom->root($node);

my $gap = Doc::Perlish::DOM::WS->new({ source => "\n\n" });

$node->add_daughter($gap);

my $para = Doc::Perlish::DOM::Element->new({ name => "para" });

$node->add_daughter($para);
my ($foo, $pi);
$para->add_daughter($foo = Doc::Perlish::DOM::Text->new
		    ({ content => "foo" }));

$node->add_daughter
    ($pi = Doc::Perlish::DOM::PI->new({ source => "\n\n=cut"}));

my @nodes;
$node->walk_down({ 'callback' => sub {
		       push @nodes, $_[0];
		   } });

is_deeply(\@nodes, [$node, $title, $text, $gap, $para, $foo, $pi],
	  "walk_down");

is_deeply($kwom, dclone($kwom), "Doc::Perlish::DOM trees storable");

nstore $kwom, 't/kwom.pm3';

