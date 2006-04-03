package Doc::Perlish;

use Doc::Perlish::Base -Base;
use Set::Object;

use Doc::Perlish::Reader;
use Doc::Perlish::DOM;
use Doc::Perlish::Parser;

our $VERSION = '0.14';

our @EXPORT_OK = qw(receiver_methods);
BEGIN {
const receiver_methods =>
    [qw( start_document end_document start_element end_element
	 characters processing_instruction ignorable_whitespace
	 final_receiver
       )];
}

field 'reader';
field 'parser';
field 'dom';

# a candidate for Spiffy?
sub delegate {
    no strict 'refs';
    my $subs = $self;
    my $where = shift;
    my %args = @_;

    for my $sub ( @$subs ) {
	*$sub = sub {
	    my $self = shift;
	    $args{pre}->($self) if $args{pre};
	    if ( ref $where ) {
		my $delegate = $where->($self);
		$self->$delegate->$sub(@_);
	    } else {
		$self->$where->$sub(@_);
	    }
	}
    };
}

# reader methods
delegate [qw(input give_me next unget type eof reset)]
    => "reader", pre => sub {
	my $self = shift;
	if ( !$self->reader ) {
	    $self->reader(Doc::Perlish::Reader->new());
	}
    };

# delegate Sender methods either to a parser, or to a constructed DOM
# object.
delegate [qw(send_all send_one receiver restart)]
    => sub {
	my $self = shift;
	if ( $self->dom ) {
	    return "dom";
	} else {
	    if ( ! $self->parser and $self->reader ) {
		# FIXME - this needs to know the document type
		# in order to create the correct type of parser
		$self->parser
		    (Doc::Perlish::Parser->create_parser
		     ($self->type,  # || any(@known_types) ;)
		      receiver => $self,
		      reader => $self,));
	    } elsif ( !$self->reader ) {
		die "can't send without a source!";
	    }
	    return "parser";
	}
    };


# receiver methods; just send 'em to the DOM object.
delegate [qw(root), @{(receiver_methods)} ]
    => "dom", pre => sub {
	my $self = shift;
	if ( !$self->dom ) {
	    $self->dom(Doc::Perlish::DOM->new());
	}
    };

sub to_dom {
    $self->send_all unless $self->dom;
    return $self->dom;
}

sub add_filter {
    my $new_filter = shift;
    my $last_sender = $self->final_sender;
    if ( $last_sender ) {
	if ( $last_sender->receiver ) {
	    $new_filter->receiver($last_sender->receiver);
	}

	$last_sender->receiver($new_filter);
    } else {
	$self->receiver($new_filter);
    }
}

sub final_sender {

    # to allow for the fact that a parser will point back to us,
    # possibly going through a filter or two, we must 
    my $head = $self->parser || $self->dom;

    if ( $head ) {
	while ( $head->can("receiver") and $head->receiver ) {
	    $head = $head->receiver;
	}
	return $head;
    } else {
	return $self;
    }
}

# what follows are largely re-interpretations of ingy's original ideas
# into things I think I can easily get to work, and fit well into the
# architecture whilst still seeming the same from a user's
# perspective.

# note that a lot of this could be considered premature, because we
# don't have schema types, and mixed document types in the core yet.

# here's the generic one that just converts the Doc::Perlish to an object
# of the specified type.  Note that this might not involve creating an
# intermediate DOM object.
sub to_class {
    my $class = shift or die "No class!";
    eval "require $class";
    #kill 2, $$;
    my $target = $class->new(@_);
    $self->receiver($target);
    $self->send_all;
    return $target;
}

# in this one, we make a "writer" class the target of the Doc::Perlish
# document.  This writer class will spit out events to its output.
sub to_xml {
    my $output;
    require Doc::Perlish::Writer::XML;
    $self->to_class("Doc::Perlish::Writer::XML", output => \$output);
    return $output;
}

# here we're seeing an extra step - the transformation of the document
# into an "HTML" document.  Here, we're taking advantage of the fact
# that the output format (HTML) can be represented using Doc::Perlish
# events, and re-use the XML writer.  Other formats might not be able
# to use this.
sub to_html {
    require Doc::Perlish::Writer::HTML;
    my $output;
    my $writer = Doc::Perlish::Writer::XML->new(output => \$output);
    my $filter = Doc::Perlish::Transform::HTML->new(receiver => $writer);
    $self->receiver($filter);
    $self->send_all;
    return $output;
}

# this one should be able to go straight to man.
sub to_nroff {
    require Doc::Perlish::Writer::Nroff;
    my $output;
    my $writer = Doc::Perlish::Writer::Nroff->new(output => \$output);
    $self->receiver($writer);
    $self->send_all;
    return $output;
}

sub to_man {
    $self->to_nroff;
}

# ...
sub doc_to_bytecode {
    $self->doc_to_class(@_, class => 'Doc::Perlish::Bytecode');
}

sub parse_to {
    require Doc::Perlish::Reader;
    require Doc::Perlish::Parser;
    my %args = @_;
    $args{reader} ||= Doc::Perlish::Reader->new(%args);
    $args{parser} ||= Doc::Perlish::Parser->new(%args);
    return $args{parser}->parse;
}


=head1 NAME

Doc::Perlish - Perl Documentation Tools

=head1 SYNOPSIS

 my $doc = Doc::Perlish->new( type => "POD", input => "source.pod" );

 # simple conversions;
 my $html = $doc->to_html;

 # DOM-style interface; see Doc::Perlish::DOM for more;
 my $dom = $doc->to_dom;

 # event-style interface;
 my $filter = Doc::Perlish::Filter->new();
 $doc->add_filter($filter);

 my $writer = Doc::Perlish::Writer::XML->new( output => "out.xml" );
 $doc->final_sender->receiver($writer);

 # run conversion!
 $doc->send_all;

=head1 DESCRIPTION

C<Doc::Perlish> is a set of tools that define and work with the I<Perldoc
Information Model>. The tools will eventally provide parsers for
various I<Doc::Perlish Dialects> (including Pod and Kwid), and formatters
for various output formats.

The C<Doc::Perlish> class, on the other hand, is an object which
simultaneously can behave like a:

=over

=item *

C<Doc::Perlish::Reader> - it can, minimally, be passed a specification of a
stream source to read and pass you pack characters or blocks or
whatever.

=item *

C<Doc::Perlish::Parser> - it can also perform the task of converting said
characters or blocks into a parsed tree, which might involve loading a
seperate dialect parser, or any of the other weird and wonderful
things that C<Doc::Perlish::Parser> is capable of.

=item *

C<Doc::Perlish::DOM> - you can call all of the parsed-state DOM methods on
it, and it will parse the entire document and then call the method

=item *

C<Doc::Perlish::Sender> - you can get Perldoc serial events out of a
Doc::Perlish object, before or after parsing!

=item *

C<Doc::Perlish::Receiver> - you can use the C<Perldoc> object as a target
for events, and let it pass them through to a destination and/or
build a DOM tree.

=back

For more details about what each component involves, and the calling
convention, see the relevant documentation for the module.

= AUTHORS

* Brian Ingerson <ingy@cpan.org>
* Sam Vilain <samv@cpan.org>

= COPYRIGHT

Copyright (c) 2005, Brian Ingerson, Sam Vilain. All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
