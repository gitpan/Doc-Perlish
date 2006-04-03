
package Doc::Perlish::Filter::Normalize;

use Doc::Perlish::Filter -Base;

sub ignorable_whitespace {

}

sub characters {
    my $data = shift;
    $data =~ s/\s+/ /g;

    $self->send("characters", $data);
}


1;

