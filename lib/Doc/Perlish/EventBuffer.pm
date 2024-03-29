
=head1 NAME

Doc::Perlish::EventBuffer - collect streaming API events

=head1 SYNOPSIS

 my $buffer = Doc::Perlish::EventBuffer->new();

 $sender->receiver($buffer);
 $sender->send_all;

 my @events = $buffer->events;

=head1 DESCRIPTION



=cut

package Doc::Perlish::EventBuffer;

use Doc::Perlish::Receiver -Base;
use Doc::Perlish::Sender -Base;
use Doc::Perlish qw(receiver_methods);

#field 'events';

BEGIN {
    no strict 'refs';
    for my $event ( @{( receiver_methods )} ) {
	*$event = sub {
	    my $self = shift;
	    push @{$self->events}, [$event, @_];
	};
    }
}

# DWIM'y array accessor
sub events {
    if ( @_ > 1 ) {
	$self->{events} = [ @_ ];
    } elsif ( @_ == 1 ) {
	my $arg = shift;
	if ( ref $arg ) {
	    $self->{events} = shift;
	} else {
	    return ${ $self->events }[$arg];
	}
    } else {
	if ( wantarray ) {
	    return @{ $self->events };
	} else {
	    return $self->{events} ||= [];
	}
    }
}

sub send_one {
    my $ev = $self->events;
    my $event = shift @$ev;
    $self->send(@$event);
    return scalar(@$ev)
}

1;
