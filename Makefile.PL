use strict;
use inc::Module::Install;

name('Doc-Perlish');
author('Sam Vilain <samv@cpan.org>');
abstract('Markup-agnostic document processing system');
license('perl');
version_from('lib/Doc/Perlish.pm');

requires(qw(
    perl 5.6.1
    Data::Dumper 0
    Scalar::Util 0
    Set::Object 1.10
    Maptastic 1.00
    Tree::DAG_Node 0
    IO::All 0.33
    IO::String 0
    Spiffy 0.30
    YAML 0
    Scriptalicious 1.04
    Perl6::Junction 0
));

build_requires(qw(
    Test::More 0.54
    Test::Base 0.42
    Class::Tangram 1.54
));

check_nmake();

clean_files("t/kwom.pm3");

&WriteAll();
