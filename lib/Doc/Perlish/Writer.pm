package Doc::Perlish::Writer;

=head1 NAME

Doc::Perlish::Writer - base class for stream output functions

=head1 SYNOPSIS

 # using - generally use a subclass
 my $writer = Doc::Perlish::Writer::XML->new();

 $doc->receiver($writer);
 $doc->send_all();

 my $output = $writer->output;  # an IO::All object

 # or, you can pass an object or specify an IO::All source
 $writer->output("filename");
 $writer->output(\$scalar);

 # to get the document body
 $writer->doc;

=head1 DESCRIPTION

A writer is something that takes Doc::Perlish Serial API events, and
converts them into a stream.

=cut

use Doc::Perlish::Base -Base;

use Scalar::Util qw(blessed);
use IO::All;

sub output {
    if ( @_ ) {
	my $where = shift;
	if ( blessed $where ) {
	    $self->{output} = $where;
	} elsif ( ref $where eq "SCALAR" ) {
	    require IO::String;
	    $self->{output} = IO::String->new($$where);
	}
    } else {
	return $self->{output} ||= io("?");
    }
}

sub doc {
    $self->{output}->seek(0,0);
    return $self->{output}->slurp;
}

sub write {
    $self->output->write(@_);
}

1;
