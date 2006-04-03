#  -*- perl -*-
#
# Tests the most basic Parser class in Doc::Perlish.
#

use Test::More tests => 3;
use Doc::Perlish::Reader;
use Doc::Perlish::DOM;
use YAML;

BEGIN{ use_ok("Doc::Perlish::Parser"); }

# the base parser class doesn't actually parse anything.  so, we use a
# test parser

BEGIN { use_ok("Doc::Perlish::Parser::XML"); }

my $reader = Doc::Perlish::Reader->new(<<XML);
<?xml version="1.0" encoding="UTF-8"?>
<foo>
  <bar>
    Here are some characters!
  </bar>
</foo>
XML

my $parser = Doc::Perlish::Parser::XML->new(reader => $reader);

my $kwom = Doc::Perlish::DOM->new();

$parser->receiver($kwom);
$parser->send_all();

is_deeply($kwom, Load(<<'YAML'), "test parser worked!")
--- !perl/Doc::Perlish::DOM
root: &1 !perl/Doc::Perlish::DOM::Element
  attr: {}
  attributes: {}
  daughters:
    - !perl/Doc::Perlish::DOM::WS
      attributes: {}
      daughters: []
      mother: *1
      name: ~
      content: "\n  "
    - &2 !perl/Doc::Perlish::DOM::Element
      attr: {}
      attributes: {}
      daughters:
        - !perl/Doc::Perlish::DOM::WS
          attributes: {}
          daughters: []
          mother: *2
          name: ~
          content: "\n    "
        - !perl/Doc::Perlish::DOM::Text
          attributes: {}
          content: Here are some characters!
          daughters: []
          mother: *2
          name: ~
        - !perl/Doc::Perlish::DOM::WS
          attributes: {}
          daughters: []
          mother: *2
          name: ~
          content: "\n  "
      mother: *1
      name: bar
    - !perl/Doc::Perlish::DOM::WS
      attributes: {}
      daughters: []
      mother: *1
      name: ~
      content: "\n"
  mother: ~
  name: foo
YAML
    or diag("Got: ".Dump($kwom));
