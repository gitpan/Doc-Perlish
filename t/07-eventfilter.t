#!perl
#
#  test some simple event filters
#
use Test::More tests => 8;

# test buffering and null filtering
BEGIN {
    use_ok("Doc::Perlish");
    use_ok("Doc::Perlish::EventBuffer");
}
my $doc = Doc::Perlish->new( type => "XML", input => "t/data/test.xml" );

# if you only want to parse once, uncomment this
# $doc->to_dom;

my $buffer1 = Doc::Perlish::EventBuffer->new();
isa_ok($buffer1, "Doc::Perlish::EventBuffer", "Perldoc::EventBuffer->new()");
$doc->receiver($buffer1);
$doc->send_all;

is(scalar @{$buffer1->events}, 69,
   "Doc::Perlish::EventBuffer catches events");

#use YAML;
#diag(YAML::Dump([$buffer1->events]));

my $buffer2 = Doc::Perlish::EventBuffer->new();

use_ok("Doc::Perlish::Filter");
my $filter = Doc::Perlish::Filter->new(receiver => $buffer2);
isa_ok($filter, "Doc::Perlish::Filter", "Perldoc::Filter->new()");

$doc->restart;
$doc->receiver($filter);
$doc->send_all;

is(scalar @{$buffer2->events}, 69, "Doc::Perlish::Filter transmits events");
is_deeply($buffer1, $buffer2, "Filter passes through events OK");



