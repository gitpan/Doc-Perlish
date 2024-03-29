
=head1 NAME

Doc::Perlish::Data::Chill - Convert Perl data structures to Perldoc

=head1 SYNOPSIS

 use Doc::Perlish::Data::Chill;

 my $chiller = Doc::Perlish::Data::Chill->new();

 $chiller->receiver(Doc::Perlish->new());
 $chiller->source($object);

 # note: send_one() will just send_all()
 $chiller->send_all();

=head1 DESCRIPTION



=cut

package Doc::Perlish::Data::Chill;

use strict;
use warnings;
use Perl6::Junction qw(any);

use Doc::Perlish::Sender -Base;

use Carp;

field "stack";

field "source";

# set to turn off indenting
field "compact";

# Just Left Compact™ - a little one-shot used for prettier compact indenting.
field "jlc";
field "indent";

field "explicit_containers";

field "visited";

sub Push {
    my $what = shift;
    $self->jlc(0);
    push(@{$self->stack}, $what);
}
sub Pop {
    $self->jlc(0);
    return pop(@{$self->stack});
}
sub Depth {
    return scalar @{$self->stack};
}
sub Unvisited {
    return $self->visited->insert(shift);
}

use Scalar::Util qw(blessed reftype);
use Set::Object qw(set);

sub send_all {
    $self->stack([]);
    $self->visited(set());
    $self->send("start_document");
    UNIVERSAL::perldoc_marshall($self->source, $self);
    $self->send("end_document");
}

sub UNIVERSAL::perldoc_marshall {
    my $obj = shift;
    my $self = shift;
    #($self, $obj) = ($obj, $self);

    $self and blessed $self or confess "identity crisis";

    if ( ref $obj and !$self->Unvisited($obj) ) {

	# this is a workaround; sometimes, for various reasons, the
	# object will be coming in with magic mysteriously dispelled.
	# So, re-bless it to fix the bits on the reference.
	if ( blessed $obj ) {
	    bless $obj, ref $obj;
	}

	$self->send("processing_instruction",
		    "error",
		    { message => ("loop in input data structure; saw "
				  ."$obj twice") });
	return;
    }

    my ($old_indent, $entered_compact);

    my ($att, $children);

    my $id;

    if ( blessed $obj and $obj->can("perldoc_chill") ) {
	$obj = $obj->perldoc_chill;
    }

    # marshall objects (apart from sets) specially
    if ( blessed $obj and !$obj->isa("Set::Object") ) {

	if ( $obj->can("perldoc_compact")
	     and $obj->perldoc_compact($self) ) {

	    $old_indent = $self->compact;
	    $entered_compact = !$old_indent;

	    $self->compact(1);

	}
	if ( $obj->can("perldoc_attr") or
	     $obj->can("perldoc_children") ) {

	    $att = ($obj->can("perldoc_attr")
		    ? $obj->perldoc_attr
		    : { } );
	    $children = ($obj->can("perldoc_children")
			 ? $obj->perldoc_children
			 : {});
	    (ref $children eq any("HASH", "ARRAY") or blessed $children)
		or die "$obj returned bad children $children";

	}
	elsif ( reftype $obj eq "HASH" ) {
	    while ( my $k = each %$obj ) {
		if ( !ref $obj->{$k} ) {
		    $att->{$k} = $obj->{$k};
		} else {
		    $children->{$k} = $obj->{$k};
		}
	    }
	}
	else {
	    die("Ref type of ".reftype($obj)
		." in object $obj not supported");
	}

	0;
	my $name = ($obj->can("perldoc_name")
		    ? $obj->perldoc_name
		    : do {
			(my $x = ref $obj)=~s{::}{}g;
			$x;
		    });

	if ( blessed $children or ref $children eq "ARRAY" ) {

	    $self->send("start_element", $name, $att);
	    $self->Push($name);
	    $self->send ("processing_instruction" => "perldoc",
			 { whitespace => "compact" })
		if $entered_compact;
	    UNIVERSAL::perldoc_marshall($children, $self);
	    $self->Pop;
	    $self->send("end_element", $name);
	}
	elsif ( keys %$children ) {

	    $self->send("start_element", $name, $att);
	    $self->Push($name);
	    $self->send ("processing_instruction" => "perldoc",
			 { whitespace => "compact" })
		if $entered_compact;

	    for my $child ( sort {$a cmp $b} keys %$children ) {
		if ( blessed $children->{$child} and
		     $children->{$child}->can("perldoc_no_proptag")
		     and $children->{$child}->perldoc_no_proptag($obj, $self)
		   ) {
		    UNIVERSAL::perldoc_marshall($children->{$child}, $self);
		} else {
		    $self->send("start_element" => $child);
		    $self->Push($child);
		    UNIVERSAL::perldoc_marshall($children->{$child}, $self);
		    $self->Pop;
		    $self->send("end_element" => $child);
		}
	    }
	    $self->Pop;
	    $self->send("end_element" => $name);
	}
	else {
	    $self->send("start_element" => $name, $att);
	    $self->send("end_element" => $name);
	}

    } elsif ( ref $obj ) {
	# a collection - Set, Array or Hash
	my $coll_tag;
	if ( ! $self->Depth or $self->explicit_containers ) {
	    $coll_tag = ucfirst lc ref $obj;
	    if ( $coll_tag eq "Set::Object" ) {
		$coll_tag = "Array";
	    }
	    $self->send("start_element" => $coll_tag);
	    $self->Push($coll_tag);
	}
	if ( reftype $obj eq "ARRAY" or blessed $obj ) {
	    for my $item ( blessed $obj ? $obj->members : @$obj ) {
		if ( defined $item ) {
		    if ( blessed $item and
			 $item->can("perldoc_no_item")
			 and $item->perldoc_no_item($obj, $self)
		       ) {
			UNIVERSAL::perldoc_marshall($item, $self);
		    } else {
			$self->send("start_element" => "item");
			$self->Push("item");
			UNIVERSAL::perldoc_marshall($item, $self);
			$self->Pop;
			$self->send("end_element" => "item");
		    }
		} else {
		    $self->send("start_element" => "item");
		    $self->send("end_element" => "item");
		}
	    }
	}
	elsif ( reftype $obj eq "HASH" ) {
	    foreach my $key ( sort keys %$obj ) {
		my $value = $obj->{$key};
		if ( defined $value ) {
		    $self->send(start_element => "item", {name => $key});
		    $self->Push("item");
		    UNIVERSAL::perldoc_marshall($value, $self);
		    $self->Pop;
		    $self->send(end_element => "item");
		} else {
		    $self->send("start_element" => "item", { name => $key });
		    $self->send("end_element" => "item");
		}
	    }
	}
	if ( $coll_tag ) {
	    $self->Pop;
	    $self->send("end_element" => $coll_tag);
	}
    } elsif ( defined $obj ) {
	$self->send(characters => $obj);
    }

    if ( $entered_compact ) {
	$self->send ("processing_instruction" => "perldoc",
		     { whitespace => "normal" });
	$self->compact($old_indent);
	$self->jlc(1);
    }
}

1;

