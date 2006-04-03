package Doc::Perlish::DOM::Text;
use Doc::Perlish::DOM::Node -Base;

=head1 NAME

Doc::Perlish::DOM::Text - text node in a Perldoc::DOM tree

=head1 SYNOPSIS

See L<Doc::Perlish::DOM::Node>.

=head1 DESCRIPTION

A C<Doc::Perlish::DOM::Text> represents a little slice of content in a Perldoc
DOM tree.

It has one property - content.

The constructor for this class has a special shortcut syntax compared
to normal C<Doc::Perlish::DOM::Node>'s / C<Tree::DAG_Node>'s - instead of
specifying options as a hash;

 Doc::Perlish::DOM::Text->new({ content => "foo", source => "foo" });

You can just say;

 Doc::Perlish::DOM::Text->new("foo");

(also, the latter form is slightly more efficient, though this is
marginal in string COW environments)

=cut

field 'content';

sub _init {
    my $o = shift;

    $self->content($o->{content}) if exists $o->{content};

    super($o);
}

sub new {
    if ( ref $_[0] ) {
	super(@_);
    } else {
	my $text = shift;
	my $o = shift || {};
	$o->{content} = $text;
	super($o);
    }
}

sub source {
    if ( @_ ) {
	super;
    } elsif ( $self->{source} ) {
	$self->{source};
    } else {
	$self->{content};
    }
}

sub dom_fields {
    super, qw(content);
}

sub dom_attr {
    my $a = super;
    if ( wantarray ) {
	my $chars = delete $a->{content};
	delete $a->{source} if (defined($a->{source}) and
				$a->{source} eq $chars);
	if ( keys %$a ) {
	    return ($chars, $a);
	} else {
	    return $chars;
	}
    } else {
	$a;
    }
}

sub event_type {
    return "characters";
}
