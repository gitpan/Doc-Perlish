package Doc::Perlish::Parser::Kwid;
use Doc::Perlish::Parser -Base;

const top_class => 'Doc::Perlish::Parser::Kwid::Top';
const class_prefix => 'Doc::Perlish::Parser::Kwid::';

sub classes {
    qw(
        AsisPhrase
        BoldPhrase
        CodePhrase
        CommentBlock
        DefinitionItem
        DefinitionList
        DocumentLink
        HeadingBlock
        HyperLink
        ItalicPhrase
        ListItem
        NamedBlock
        NamedPhrase
        OrderedList
        TextParagraph
        UnorderedList
        UrlLink
        VerbatimBlock
    );
}

################################################################################
package Doc::Perlish::Parser::Kwid::Top;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'top';
const contains => [qw( comment named pre dlist ulist olist para )];

sub parse {
    $self->receiver->begin('stream');
    my $buffer = $self->reader->buffer;
    my $table = $self->table;
    my $contains = $self->contains;
    while (not $self->the_end) {
        my $matched = 0;
        for my $id (@$contains) {
            warn $id,"\n";
            my $class = $table->{$id} or next;
            next unless $class->can('start_patterns');

	    # ingy, what are you trying to achieve with this?

	    # I mean, I can see quite clearly what you're trying to
	    # do.  But why create a new parser with every single
	    # token?
            if ($self->match_start($buffer, $class)) {
                $self->create_parser($class)->parse;
                $matched++;
                last;
            }
        }
        die "No Rule to match:\n" . $$buffer;
    }
    $self->receiver->end('stream');
}

sub match_start {
    my $buffer = shift;
    my $class = shift;
    warn $class, "\n";
    my $patterns = $class->start_patterns;
    for my $pattern (@$patterns) {
        return 1 if $$buffer =~ $pattern;
    }
    return 0;
}

sub the_end {
    $self->reader->eos;
}

################################################################################
package Doc::Perlish::Parser::Kwid::TextParagraph;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'para';
const start_patterns => [qr{^.}];
const contains => [qw(bold italic text)];

sub parse {
    XXX $self;
}



################################################################################
package Doc::Perlish::Parser::Kwid::NamedBlock;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'named';
const start_patterns => [qr{^\.\w+}];

sub parse {
    # Load the sub parsing module
    # Invoke a subparse
}

################################################################################
package Doc::Perlish::Parser::Kwid::VerbatimBlock;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'pre';

################################################################################
package Doc::Perlish::Parser::Kwid::DefinitionList;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'dlist';

################################################################################
package Doc::Perlish::Parser::Kwid::UnorderedList;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'ulist';

################################################################################
package Doc::Perlish::Parser::Kwid::OrderedList;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'olist';

################################################################################
package Doc::Perlish::Parser::Kwid::BoldPhrase;
use base 'Doc::Perlish::Parser::Kwid';
const id => 'bold';

################################################################################
package Doc::Perlish::Parser::Kwid::ItalicPhrase;
use base 'Doc::Perlish::Parser::Kwid';

################################################################################
package Doc::Perlish::Parser::Kwid::CodePhrase;
use base 'Doc::Perlish::Parser::Kwid';

__END__

################################################################################
sub parse {
    my $result = $self->do_parse;
}

sub do_parse {
    $self->receiver->begin({type => 'stream'});
    while (my $block = $self->next_block) {
        $self->receiver->begin($block);
        $self->reparse($block);
        $self->receiver->end($block);
    }
    $self->receiver->end({type => 'stream'});
    return $self->finish;
}

sub reparse {
    my $chunk = shift;
    my $type = $chunk->{type};
    my $class = "Doc::Perlish::Parser::$type";
    my $parser = $class->new(
        input => \$chunk->{content},
        receiver => $self->receiver,
    );
    $parser->parse;
}

sub contains_blocks {
    qw( heading verbatim paragraph )
}

sub next_block {
    $self->throwaway
      or return;
    for my $type ($self->contains_blocks) {
        my $method = "get_$type";
        my $block = $self->$method;
        next unless defined $block;
        $block = { content => $block }
          unless ref $block;
        $block->{type} ||= $type;
        return $block;
    }
    return;
}

sub throwaway {
    while (my $line = $self->read) {
        next if
          $self->comment_line($line) or
          $self->blank_line($line);
        $self->unread($line);
        return 1;
    }
    return;
}

sub read_paragraph {
    my $paragraph = '';
    while (my $line = $self->read) {
        last if $self->blank_line($line);
        $paragraph .= $line;
    }
    return $paragraph;
}

sub comment_line { (pop) =~ /^#\s/ }
sub blank_line { (pop) =~ /^\s*$/ }
sub line_matches {
    my $regexp = shift;
    my $line = $self->read;
    $self->unread($line);
    $line =~ $regexp;
}

# Methods to parse out top level blocks
sub get_heading {
    return unless $self->line_matches(qr/^={1,4} \S/);
    my $heading = $self->read_paragraph;
    $heading =~ s/\s*\n\s*(?=.)/ /g;
    chomp $heading;
    $heading =~ s/^(=+)\s+// or die;
    my $level = length($1);
    return +{
        content => $heading,
        level => $level,
    };
}

sub get_verbatim { 
    my $verbatim = '';
    my $prev_blank = 0;
    while (my $line = $self->read) {
        if ($line =~ /^\S/) {
            if ($prev_blank) {
                $self->unread($line);
                last;
            }
            $self->unread($verbatim, $line);
            return;
        }
        next if $self->comment_line($line);
        $verbatim .= $line;
        $prev_blank = $self->blank_line($line);
    }
    return unless $verbatim;
    until ($verbatim =~ /^\S/) {
        $verbatim =~ s/^ //gm;
    }
    return $verbatim;
}

sub get_paragraph {
    my $paragraph = $self->read 
      or return;
    while (my $line = $self->read) {
        next if $self->comment_line($line);
        last if $self->blank_line($line);
        $paragraph .= $line;
    }
    $paragraph =~ s/\s*\n(?=.)/ /g;
    return $paragraph;
}

# Methods to handle reading and buffering input
package Doc::Perlish::Parser::Unit;
our @ISA = qw(Doc::Perlish::Parser);

sub do_parse {
    $self->receiver->content(${$self->input});
}

sub reparse {
    die;
}

package Doc::Perlish::Parser::heading;
use base 'Doc::Perlish::Parser::Unit';

package Doc::Perlish::Parser::verbatim;
use base 'Doc::Perlish::Parser::Unit';

package Doc::Perlish::Parser::paragraph;
use base 'Doc::Perlish::Parser::Unit';
