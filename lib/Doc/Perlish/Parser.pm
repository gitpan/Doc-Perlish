package Doc::Perlish::Parser;

=head1 NAME

Doc::Perlish::Parser - parse Perldoc input documents to events

=head1 SYNOPSIS

  use Doc::Perlish::Parser;

  my $parser = Doc::Perlish::Parser->create_parser("kwid");

  my $dom = Doc::Perlish::DOM->new();
  $parser->receiver($dom);

  my $reader = Doc::Perlish::Reader->new();
  $parser->reader($reader);

  $parser->send_all;   # or ->parse()

=head1 DESCRIPTION

A Doc::Perlish parser is something that uses a reader to send events.

=cut

use Doc::Perlish::Sender -Base;

field 'reader';

sub parse {
    $self->send_all;
}

sub restart {
    $self->reader->reset;
    super;
}

=head1 SKELETON SUB-CLASS API

To make a sub-class of the Doc::Perlish parser that parses an arbitrary
file format, just define C<send_one()> in your sub-class (see
L<Doc::Perlish::Sender>).  This method should read characters from
C<$self-E<gt>reader>, and put back anything it doesn't consume.

=head1 PERLDOC SUB-CLASS API

However, to be a true C<Doc::Perlish> dialect, it should do a little more
than that.  Doc::Perlish documents support nested parsers and dialects, but
the C<Doc::Perlish::Sender> API requires that only a single object is used
to send events.

In this case, you would define just C<parse_one()>

=over

=cut

field 'parent';
field top =>
      -init => \&set_top;
sub set_top {
    $self->parent ? $self->parent->top : $self;
}

field 'child';
sub send_one {
    if ( $self->child ) {
	$self->child->send_one($self->top);
    } elsif ( $self->can("parse_one") ) {
	$self->parse_one(@_);
    } else {
	die "$self doesn't know how to parse_one()!";
    }
}

=item C<__PACKAGE__-E<gt>register($type)>

This registers the type of your parser with the C<Doc::Perlish::Parser>
parser factory.  This should be called when the module for your
dialect loads.

This can be called explicitly as;

  Doc::Perlish::Parser::register($package, $type)

In that case, the C<$package> will be automatically required the first
time a document or fragment of that type is processed.

=item C<-E<gt>parser_class($type)>

Returns what package is registered to the passed type, if any.

=cut

# this is our parser factory.
const config => {
    parsers => {
        pod  => 'Doc::Perlish::Parser::Pod',
        kwid => 'Doc::Perlish::Parser::Kwid',
        xml => 'Doc::Perlish::Parser::XML',
    }
};

sub register {
    my $type = shift;
    $self->config->{parsers}{$type} = $self;
}

sub parser_class {
    my $type = shift;
    $self->config->{parsers}{lc($type)}
}

=item C<-E<gt>create_parser($type, @newopts)>

This constructor, which may be called as a class or object method,
creates a new Parser of the designated type.

Anything after the C<$type> is passed to the constructor of the new
parser.

=cut

sub create_parser {
    my $type = shift;
    my $class = $self->parser_class($type)
	or die "unknown Doc::Perlish dialect '$type'";

    unless ( defined &{$class."::new"} ) {
	eval "require $class";
	die $@ if $@;
    }

    $class->new( @_ );
}

=item C<-E<gt>child_parser($type, @newopts)>

A variant on the above constructor, this one automatically marks the
new parser as being a child of this one, and passes through the
reader.  It also sets the new parser as being the current recipient
for receiving events.

This is only available as an object method.  This is typically used
when switching dialects.

=cut

sub child_parser {
    my $type = shift;
    my $class = $self->parser_class($type)
	or die "unknown Doc::Perlish dialect '$type'";

    $self->child(
		 $class->new( parent => $self,
			      reader => $self->reader,
			      @_ )
		);
}

=item C<-E<gt>resign()>

This causes a child parser to finish parsing and pass control to the
parent parser's C<send_one()> method.

=cut

sub resign {
    my $parent = $self->parent;
    $parent->abandon($self);
    $parent->send_one($self->top);
}

sub abandon {
    $self->child(undef);
}

# I really think that this sort of thing categorically isn't Parser
# stuff.  It's document structure and grammar, not text form!

field table =>
      -init => '$self->create_table';
sub create_table {
    my $class_prefix = $self->class_prefix;
    my %table = map {
        my $class = /::/ ? $_ : "$class_prefix$_";
        $class->can('id') ? ($class->id, $class) : ();
    } $self->classes;
    \ %table;
}

package Doc::Perlish::Parser::Block;

package Doc::Perlish::Parser::Phrase;

1;

