package Doc::Perlish::DOM::Node;

use base 'Tree::DAG_Node';

use Spiffy -Base;

use Carp;

=head1 NAME

Doc::Perlish::DOM::Node - node in a Perldoc::DOM tree

=head1 SYNOPSIS

 # construct a Doc::Perlish::DOM fragment from this:
 #
 #  =head1 NAME
 #
 #  foo
 #
 #  =cut
 #
 # corresponding normative XML tree;
 #
 #  <sect1><title>NAME</title><para>foo</para></sect1>

 # Doc::Perlish::DOM::Node representation;
 my $node = Doc::Perlish::DOM::Element->new
     ({ name => "sect1",
        source => "=head1 ",  # text "eaten" by this node
     });


 # no "source", as this is an "implied" tag
 my $title = Doc::Perlish::DOM::Element->new ({ name => "title" });
 $node->add_daughter($title);

 # text nodes are different, like W3C DOM - don't moan
 # kiddies, this is for your own good :)
 my $text = Doc::Perlish::DOM::Text->new ("NAME");

 # note that Texts *can* have an alternate source fragment, but it
 # defaults to be the same as the content, modulo whatever we end up
 # doing with whitespace for the round-tripping

 $title->add_daughter($text);

 # etc etc
 my $para = Doc::Perlish::DOM::Element->new({ name => "para",
                                      source => "\n\n" });
 $node->add_daughter($para);
 # alternate way of creating Texts with content
 $para->add_daughter(Doc::Perlish::DOM::Text->new
                         ({ content => "foo" }));

 # dummy nodes used only for reconstruction to source.
 # represented as processing instructions, or maybe comments
 # in the "normative XML"
 $node->add_daughter
    (Doc::Perlish::DOM::PI->new({ source => "\n\n=cut"}));

=head1 DESCRIPTION

Well, with that informative but utterly confusing synopsis, you should
be left with nothing but questions about what this object represents.

It represents a node in the Doc::Perlish DOM tree (see L<Perldoc::DOM> for more).
The DOM tree has a root node, which is a "C<body>" element of sorts.

Different types of nodes in a Doc::Perlish DOM tree have different properties,
you should see the subclasses for more.

In short, those subclasses are;

=over

=item L<Doc::Perlish::DOM::Element>

It's all about meta-data and structure, not content!

=item L<Doc::Perlish::DOM::Text>

The Text nodes are where it's at, baby, yeah!

=item L<Doc::Perlish::DOM::PI>

Placeholder for dummy nodes that contain only source representation.

=back

=head1 API METHODS

These methods must be implemented by subclasses... though a default
implementation exists, too.

=over

=item B<source>

=item B<source($new_source)>

Returns the representation of this node in the original text, or at
least a valid representation of it that "honours the spirit of the
dialect", if the original form is not available or has been discarded.

=cut

field 'source';
field 'sourcefile';
field 'sourceline';

sub _init {
    my $o = shift;

    $self->SUPER::_init($o);

    $self->source($o->{source}) if defined $o->{source};

    super($o);
}

sub new {
    my $class = ref $self || $self;
    $class ne __PACKAGE__ or croak "attempt to create a pure Node";

    super(@_);
}

sub dom_fields {
    qw(source sourcefile sourceline);
}

sub dom_attr {
    return { map { defined($self->$_) ? ($_ => $self->$_) : () }
	     $self->dom_fields };
}

__END__

=head1 SEE ALSO

L<Tree::DAG_Node> - details on how to navigate the DAG.

=cut

