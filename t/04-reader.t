#  -*- perl -*-
#
#  Test for the Doc::Perlish::Reader class.  This is a very simple wrapper
#  for IO::All et al.
#

use Test::More tests => 7;

use_ok("Doc::Perlish::Reader");

my $reader = Doc::Perlish::Reader->new("t/testdoc.pod");
isa_ok($reader, "Doc::Perlish::Reader", "new reader");

$reader->give_me("characters");

my $buffer;
while ( !$reader->eof ) {
    my $next = $reader->next;
    $buffer .= $next if defined $next;
}

is(length($buffer), 127, "can read character by character");
like($buffer, qr/dummy/, "read returns data");

$reader->reset;

$reader->give_me("lines");

my $c;
while ( !$reader->eof ) {
    $c ++;
    $reader->next;
}

is($c, 12, "can read line by line");

$reader->reset;
$reader->give_me("paragraphs");

$c = 0;
while ( !$reader->eof ) {
    $c ++;
    $reader->next;
}
is($c, 5, "can read paragraph by paragraph");

# test string reader
$reader = Doc::Perlish::Reader->new("hello\nthere");
is($reader->next, "hello\nthere", "can use reader on strings");
