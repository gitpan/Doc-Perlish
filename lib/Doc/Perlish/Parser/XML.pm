package Doc::Perlish::Parser::XML;

use Doc::Perlish::Parser -Base;

=head1 NAME

Doc::Perlish::Parser::XML - parse eXecrable Markup Language into Perldoc

=head1 SYNOPSIS

 my $reader = Doc::Perlish::Reader->new("foo.xml");

 my $parser = Doc::Perlish::Parser::XML->new(reader => $reader);

 $parser->receiver(Doc::Perlish::DOM->new());

 $parser->send_all;

=head1 DESCRIPTION

This is a dummy parser for Doc::Perlish documents.  It parses a nonsense
encoding of documents that is derived from an old standard known as
SGML, that was invented in the days when human time was a lot cheaper
than CPU time.

The derivative of the standard, however, was invented in a time when
this was not the case, so it is not quite clear as to why such an
archaic form was adopted in a widespread fashion.  It is speculated
that it might have had something to do with the popularity of a
particular dialect of SGML known as HTML.

The theory goes like this: many monkeys learnt HTML, and thought that
they were special and that HTML was magic, instead of moving on to
real languages and protocols they instead tried to move the world to
make HTML (or its generalised form, SGML, rebranded as "XML") the
standard for everything from documents (its original problem domain)
to data exchange, but

  Those who wish to change the world
  According with their desire
  Cannot succeed.
  
  The world is shaped by the Way;
  It cannot be shaped by the self.
  Trying to change it, you damage it;
  Trying to possess it, you lose it.

  -- from Gnu's Not Lao, chapter 29

And so, people got on this mad bandwagon to nowhere now known as XML.

This module is primarily used for testing, to supply a I<degenerate>
test case.  Note the I<emphasis> in that last sentence.  It does not
attempt to parse anything more than a very basic level of XML.  Any
requests to make it more fully featured may be told to stick it up
their own source repository, unless they are impressively small
C<:-)>.

(seriously, if you do want to make a proper XML input stage for this,
feel free to use some real XML library and send a patch, or release a
seperate dist - but I don't want to introduce such a dependancy into
the test suite at this point).

=cut

my %ents = ("amp" => "&",
	    "lt" => "<",
	    "gt" => ">");

my $ent_qr = "&(" . join("|", keys %ents) . ");";
$ent_qr = qr/$ent_qr/;

sub decode {
    my $string = shift;
    $string =~ s{&(amp|lt|gt);}{$ents{$1}}gi;
    $string;
}

sub send_one {

    # make this parser slightly more efficient by pulling tokens at a
    # time :)
    $self->reader->give_me(qr/<[^>]+>|[^<]+/s);
    my $state = "pu";

    my $buffer = $self->reader->next;

    if ( defined $buffer ) {
	if ( (substr $buffer, 0, 1) eq "<" ) {
	    $state = "tag";
	}
	else {
	    $state = "chars";
	    if ( (substr $buffer, -1) eq "\n" ) {
		my @lines;
		while ( defined(my $next_token = $self->reader->next)
		      ) {
		    if ( substr($next_token,0,1) eq "<" ) {
			$self->reader->unget($next_token);
			last;
		    } else {
			push @lines, $next_token;
		    }
		}
		$buffer = join "", $buffer, @lines if @lines;
	    }
	}
    }

    if ( $state eq "tag" ) {
	if ( $buffer =~ m{\A<([a-zA-Z_0-9:]+)([^>]*?)(/)?\s*>\Z}) {
	    my $tag = $1;
	    my $attr = $2;
	    my $is_closing = $3;
	    my %attr;
	    while ($attr =~ s{\A\s*([a-z_A-Z0-9:]+)
			      \s*=\s*
			      (?:'([^']*)'|"([^"]*)")}{}x) {
		$attr{$1} = $self->decode(defined $2 ? $2 : $3);
	    }
	    $self->send("start_element", $tag, \%attr);
	    $self->send("end_element", $tag) if $is_closing;
	}
	elsif ( $buffer =~ m{\A</([a-zA-Z_0-9:]+)\s*>\Z} ) {
	    $self->send("end_element", $1);
	}
	elsif ( $buffer =~ m{\A<\?([a-zA-Z0-9:]+)[^>]*\?>\Z} ) {
	    # FIXME - processing_instruction
	}
	else {
	    die "Bizarre tag-like sequence: `$buffer'";
	}
    }
    elsif ( $state eq "chars" ) {
	#local($Doc::Perlish::Sender::DEBUG)=1;
	if ( $buffer =~ s{\A(\s+)}{}s ) {
	    my $ws = $1;
	    $self->send("ignorable_whitespace", $ws)
		if ($self->sendstate
		    and $self->sendstate eq "body"); # else drop!
	}

	my ($data, $trailing) = ($buffer =~ m{\A(.*?)(\s*)\Z}s);

	if ( length $data ) {
	    $self->send("characters", $self->decode($data));
	}

	if ( length $trailing ) {
	    $self->send("ignorable_whitespace", $trailing);
	}
    }
    else {
	warn "Got nothing; $buffer" unless $self->reader->eof;
    }

    return ($self->reader->eof ? $self->send("end_document") : 1);
}

1;
