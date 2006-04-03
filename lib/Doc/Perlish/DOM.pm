package Doc::Perlish::DOM;
use Spiffy -Base;

use base 'Doc::Perlish::Sender';
use base 'Doc::Perlish::Receiver';

use Doc::Perlish::DOM::Node;
use Doc::Perlish::DOM::Element;
use Doc::Perlish::DOM::PI;
use Doc::Perlish::DOM::WS;
use Doc::Perlish::DOM::Text;

=head1 NAME

Doc::Perlish::DOM - Represent a Perldoc document, DOM-style

=head1 SYNOPSIS

 $kwoc = new Doc::Perlish::DOM();

 my $body = $kwoc->root();
 my @next = $body->daughters();

 my $node = $kwoc->klink("S09#//para/");  # KLINK lookup

=head1 DESCRIPTION

A Doc::Perlish::DOM is a directed acyclic graph, which is a Computer
Scientist's way of saying "tree" (cue: the Fast Show "aliens that say
'tree' skit").

=head1 CREATING A Doc::Perlish::DOM TREE

C<Doc::Perlish::DOM> trees are seldom created using the C<Tree::DAG_Node>
interface.

Normally, they will be constructed as a series of events fired in by a
L<Doc::Perlish::Sender>, such as another L<Perldoc::DOM>, a
L<Doc::Perlish::Preprocessor>, or a L<Perldoc::Parser>.

=cut

field 'root';  # is "Doc::Perlish::DOM::Element"

sub new {
    my $class = ref $self || $self;

    $self = super;

    $self->root(Doc::Perlish::DOM::Element->new({name => "pod"}));

    return $self;
}

field 'dom_sendstate';

use Scalar::Util qw(blessed);

=head1 METHODS

=over

=item B<$dom-E<gt>receiver($object)>

=item B<$dom-E<gt>send_one()>

=item B<$dom-E<gt>send_all()>

Doc::Perlish::DOM supports the C<Perldoc::Sender> API.

=cut

sub send_one {
    my $source = shift || $self;
    my $dss = $self->dom_sendstate;
    if ( !$dss ) {
	$self->dom_sendstate
	    ($dss =
	     { head => undef,
	       state => undef,
	     });
    }
    local($YAML::UseHeader) = 1;
    #kill 2, $$ if $dss->{state} eq "post";
    #print STDERR "state: { state => $dss->{state}, head => ".(ref($dss->{head})||$dss->{head}||"undef")." }\n";

    if ( !$dss->{state} ) {
	$dss->{state} = "pre";
	$source->send("start_document");
	$dss->{head} = $self->root;
    } elsif ( $dss->{state} eq "pre" and $dss->{head} ) {

	if ( $dss->{head}->isa("Doc::Perlish::DOM::Element") ) {
	    $source->send("start_element",
			$dss->{head}->name,
			$dss->{head}->dom_attr);
	    $dss->{state} = "pre";
	    $dss->{head} = (($dss->{head}->daughters)[0]) ||
		(($dss->{state} = "post"), $dss->{head});
	} else {
	    $source->send($dss->{head}->event_type,
			$dss->{head}->dom_attr);
	    $dss->{head} = $dss->{head}->right_sister ||
		(($dss->{state} = "post"), $dss->{head}->mother);
	}

    } elsif ( $dss->{state} eq "post" ) {
	if ( $dss->{head} && $dss->{head}->name ) {
	    $source->send("end_element", $dss->{head}->name);
	    $dss->{state} = "pre";
	    $dss->{head} = $dss->{head}->right_sister ||
		(($dss->{state} = "post"), $dss->{head}->mother);
	} else {
	    $source->send("end_document");
	    delete $self->{dom_sendstate};
	    return 0;
	}
    }
    return 1;
}

field "dom_buildstate";

=item B<$dom-E<gt>restart()

Clear the state of the C<Doc::Perlish::Sender>, useful for guaranteeing
that you don't get a partial tree out of your DOM object.

=cut

sub restart {
    super;
    delete $self->{dom_sendstate};
}

=item B<$dom-E<gt>start_document()>

=item B<$dom-E<gt>end_document()>

=item B<$dom-E<gt>start_element($name, \%o)>

=item B<$dom-E<gt>end_element([$name])>

=item B<$dom-E<gt>characters($data, [\%o])>

=item B<$dom-E<gt>processing_instruction([\%o])>

=item B<$dom-E<gt>ignorable_whitespace([\%o])>

Supports the C<Doc::Perlish::Receiver> API.

=item B<$dom-E<gt>make_element($name, \%o)>

=item B<$dom-E<gt>make_text($data, [\%o])>

=item B<$dom-E<gt>make_pi(\%o)>

=item B<$dom-E<gt>make_ws(\%o)>

Sub-classes of C<Doc::Perlish::DOM> may wish to override these methods,
which are called when creating nodes during DOM tree construction.

=cut

sub start_document {
    $self->root(undef);
    $self->dom_buildstate({ head => undef,
			  });
}

sub end_document {
    delete $self->{dom_buildstate};
}

sub make_element {
    my $name = shift;
    my $o = shift || {};
    $o->{name} = $name;
    return Doc::Perlish::DOM::Element->new($o);
}
sub make_text {
    return Doc::Perlish::DOM::Text->new(@_);
}
sub make_pi {
    return Doc::Perlish::DOM::PI->new(@_);
}
sub make_ws {
    my $whitespace = shift;
    #print STDERR "Building whitespace node: `$whitespace'\n";
    return Doc::Perlish::DOM::WS->new($whitespace);
}

sub start_element {
    my $dbs = $self->dom_buildstate or die;
    my $node = $self->make_element(@_);

    if ( my $head = $dbs->{head} ) {
	$head->add_daughter($dbs->{head} = $node);
    } else {
	$self->root($dbs->{head} = $node);
    }
}

sub end_element {
    my $dbs = $self->dom_buildstate or die;
    $dbs->{head} or die "too many end element events!";

    $dbs->{head} = $dbs->{head}->mother
}

sub characters {
    my $dbs = $self->dom_buildstate or die;
    my $node = $self->make_text(@_);
    $dbs->{head}->add_daughter($node);
}

sub processing_instruction {
    my $dbs = $self->dom_buildstate or die;
    my $node = $self->make_pi(@_);
    $dbs->{head}->add_daughter($node) if $node;
}

sub ignorable_whitespace {
    my $dbs = $self->dom_buildstate or die;
    my $node = $self->make_ws(@_);
    $dbs->{head}->add_daughter($node) if $node and $dbs->{head};
}

1;
