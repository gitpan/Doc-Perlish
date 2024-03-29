
package Doc::Perlish::Filter;

use Doc::Perlish::Sender -Base;
use Doc::Perlish::Receiver -Base;

BEGIN {
    no strict 'refs';
    for my $event (qw (start_document end_document
		       start_element end_element
		       characters
		       processing_instruction
		       ignorable_whitespace )) {
	*$event = sub {
	    my $self = shift;
	    $self->send($event, @_);
	}
    }
}

our $DEBUG = 0;

sub DEBUG {
    $DEBUG;
}



sub send_one {
    #print "Sending: ".Doc::Perlish::Sender->_format(@_);
    $self->sender->send_one(@_);
}

1;
