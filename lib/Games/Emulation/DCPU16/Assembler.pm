package Games::Emulation::DCPU16::Assembler;
use strict;
use warnings;

sub new {
    my $class = shift;
    bless {
        bytes      => '',
        line       => 0,

        labels     => {},
        unresolved => {},

        basic_ops => {
            SET => 0x01,
            ADD => 0x02,
            SUB => 0x03,
            MUL => 0x04,
            DIV => 0x05,
            MOD => 0x06,
            SHL => 0x07,
            SHR => 0x08,
            AND => 0x09,
            BOR => 0x0a,
            XOR => 0x0b,
            IFE => 0x0c,
            IFN => 0x0d,
            IFG => 0x0e,
            IFB => 0x0f,
        },
        non_basic_ops => {
            JSR => 0x01,
            HLT => 0x3f,
        },
        registers => {
            A => 0x00,
            B => 0x01,
            C => 0x02,
            X => 0x03,
            Y => 0x04,
            Z => 0x05,
            I => 0x06,
            J => 0x07,
        },
    }, $class;
}

sub bytes { shift->{bytes} }

sub assemble {
    my $self = shift;
    my ($script) = @_;

    for my $line (split /\n/, $script) {
        $self->parse_line($line);
    }

    $self->resolve_references;

    return $self->{bytes};
}

sub parse_line {
    my $self = shift;
    my ($line) = @_;

    $self->{line}++;

    my $clean_line = $self->_clean_line($line);
    return unless length($clean_line);

    my ($label, $op, $a, $b) = $clean_line =~ m!
        ^              \s*
        (?::(\w+)      \s+)?
        ([A-Z]{3})     \s+
        ([^,\s]+) (?:, \s+
        ([^,\s]+))?    \s*
        $
    !x;

    die "Couldn't parse \"$line\" (line $self->{line})"
        unless defined $op;

    $self->{labels}{$label} = length($self->{bytes}) / 2
        if defined $label;

    $op = uc($op);
    if (my $basic_opcode = $self->{basic_ops}{$op}) {
        die "$op requires two values (line $self->{line})"
            unless defined($b);

        my ($val1, $next_word1, $label1) = $self->_parse_value($a);
        my ($val2, $next_word2, $label2) = $self->_parse_value($b);

        $basic_opcode |= $val1 << 4;
        $basic_opcode |= $val2 << 10;

        $self->{unresolved}{length($self->{bytes}) / 2} = [ $label1, $label2 ]
            if defined($label1) || defined($label2);

        $self->{bytes} .= pack("S>", $basic_opcode);
        $self->{bytes} .= pack("S>", $next_word1) if defined $next_word1;
        $self->{bytes} .= pack("S>", $next_word2) if defined $next_word2;
    }
    elsif (my $non_basic_opcode = $self->{non_basic_ops}{$op}) {
        my ($val, $next_word, $label) = $self->_parse_value($a);

        $non_basic_opcode <<= 4;
        $non_basic_opcode |= $val << 10;

        $self->{unresolved}{length($self->{bytes}) / 2} = [ $label ]
            if defined($label);

        $self->{bytes} .= pack("S>", $non_basic_opcode);
        $self->{bytes} .= pack("S>", $next_word) if defined $next_word;
    }
    else {
        die "Invalid op: $op (line $self->{line})";
    }
}

sub resolve_references {
    my $self = shift;

    for my $pos (reverse sort { $a <=> $b } keys %{ $self->{unresolved} }) {
        my @labels = grep { defined } @{ delete $self->{unresolved}{$pos} };
        next unless @labels;

        my $offset = 2;
        for my $label (@labels) {
            die "Unknown label $label (during resolution)"
                unless exists $self->{labels}{$label};

            # XXX collapse small integers
            substr(
                $self->{bytes},
                $pos * 2 + $offset,
                2,
                pack("S>", $self->{labels}{$label})
            );
            $offset += 2;
        }
    }
}

sub _clean_line {
    my $self = shift;
    my ($line) = @_;

    $line =~ s/;.*//;
    $line =~ s/^\s*|\s*$//;
    $line =~ s/\s+/ /g;

    return $line;
}

sub _parse_value {
    my $self = shift;
    my ($value) = @_;

    my $reg = qr/[ABCXYZIJ]/;
    my $num = qr/(?:0[xb])?[0-9]+/;

    if ($value =~ /^($reg)$/) {
        return ($self->{registers}{$1});
    }
    elsif ($value =~ /^\[\s*($reg)\s*\]$/) {
        return (0x08 + $self->{registers}{$1});
    }
    elsif ($value =~ /^\[\s*($num)\s*\+\s*($reg)\s*\]$/) {
        return (0x10 + $self->{registers}{$2}, $self->_parse_num($1));
    }
    elsif ($value eq 'POP'  || $value =~ /^\[\s*SP\+\+\s*\]$/) {
        return (0x18);
    }
    elsif ($value eq 'PEEK' || $value =~ /^\[\s*SP\s*\]$/) {
        return (0x19);
    }
    elsif ($value eq 'PUSH' || $value =~ /^\[\s*--SP\s*\]$/) {
        return (0x1a);
    }
    elsif ($value eq 'SP') {
        return (0x1b);
    }
    elsif ($value eq 'PC') {
        return (0x1c);
    }
    elsif ($value eq 'O') {
        return (0x1d);
    }
    elsif ($value =~ /^\[\s*($num)\s*\]$/) {
        return (0x1e, $self->_parse_num($1));
    }
    elsif ($value =~ /^($num)$/) {
        my $num = $self->_parse_num($1);
        if ($num < 0x20) {
            return 0x20 + $num;
        }
        else {
            return (0x1f, $self->_parse_num($1));
        }
    }
    elsif ($value =~ /\w+/) {
        return (0x1f, 0x00, $value);
    }
    else {
        die "Can't parse value \"$value\" (line $self->{line})";
    }
}

sub _parse_num {
    my $self = shift;
    my ($num) = @_;

    die "Invalid number $num (line $self->{line})"
        unless $num =~ /^(?:0[xb])?[0-9]+/;

    my $decimal = $num;
    $decimal = oct($num) if $num =~ /^0/;

    die "Number $decimal too large (line $self->{line})"
        if $decimal >= 2**16;

    return $decimal;
}

1;
