package Games::Emulation::DCPU16;
use strict;
use warnings;

use integer;

use constant {
    STATE_NEW_OP     => 0,
    STATE_READ_ARG_1 => 1,
    STATE_READ_ARG_2 => 2,
    STATE_OP_EXECUTE => 3,
    TIME_TAKEN_NONE  => 0,
    TIME_TAKEN_DELAY => 1,
    TIME_TAKEN_WORK  => 2,
};

sub new {
    my $class = shift;

    bless {
        memory           => [(0x0000) x 0x10000],
        registers        => [(0x0000) x 8],
        PC               => 0x0000,
        SP               => 0x0000,
        O                => 0x0000,

        halt             => undef,
        delay            => 0,
        time_taken       => TIME_TAKEN_NONE,
        state            => STATE_NEW_OP,
        has_delayed      => undef,

        current_op       => undef,
        lvalue           => undef,
        value1           => undef,
        value2           => undef,
        next_word        => undef,

        basic_opcode_map => [
            undef,
            '_op_SET',
            '_op_ADD',
            '_op_SUB',
            '_op_MUL',
            '_op_DIV',
            '_op_MOD',
            '_op_SHL',
            '_op_SHR',
            '_op_AND',
            '_op_BOR',
            '_op_XOR',
            '_op_IFE',
            '_op_IFN',
            '_op_IFG',
            '_op_IFB',
        ],
        non_basic_opcode_map => [
            undef,
            '_op_JSR',
            (undef) x (0x3f - 0x02 - 1),
            '_op_HLT', # XXX extension
        ],
    }, $class;
}

sub memory    { shift->{memory}    }
sub registers { shift->{registers} }
sub PC        { shift->{PC}        }
sub SP        { shift->{SP}        }
sub O         { shift->{O}         }

sub load {
    my $self = shift;
    my ($bytecode) = @_;

    my $idx = 0;
    while (my $word = substr($bytecode, 0, 2, '')) {
        $self->{memory}[$idx++] = ord($word) * 2**8 + ord(substr($word, 1, 1));
    }
}

sub run {
    my $self = shift;

    $self->step until $self->{halt};
}

sub step {
    my $self = shift;

    if ($self->{delay}) {
        $self->{delay}--;
        return;
    }

    $self->{time_taken} = TIME_TAKEN_NONE;
    while (1) {
        my $state = $self->{state};
        if ($state == STATE_NEW_OP) {
            $self->{state} = $self->_parse_op($self->{memory}[$self->{PC}++]);
        }
        elsif ($state == STATE_READ_ARG_1) {
            $self->{state} = $self->_parse_value($self->{value1})
        }
        elsif ($state == STATE_READ_ARG_2) {
            $self->{state} = $self->_parse_value($self->{value2})
        }
        elsif ($state == STATE_OP_EXECUTE) {
            $self->{state} = $self->_execute_current_op;
        }
        else {
            die "Invalid state";
        }

        last if $self->{time_taken} != TIME_TAKEN_NONE;
    }
}

# XXX this duplicates a bit from _parse_value
sub _op_length {
    my $self = shift;

    my $length = 1;
    $self->_parse_op($self->{memory}[$self->{PC}]);

    for my $value ($self->{value1}, $self->{value2}) {
        next unless defined $value;
        $length++ if $value >= 0x10 && $value < 0x18;
        $length++ if $value >= 0x1e && $value < 0x20;
    }

    return $length;
}

sub _parse_op {
    my $self = shift;
    my ($opcode) = @_;

    my $basic_op = $opcode & 0x0f;

    if ($basic_op) {
        $self->{value1}     = ($opcode >> 4)  & 0x3f;
        $self->{value2}     = ($opcode >> 10) & 0x3f;
        $self->{current_op} = $self->{basic_opcode_map}[$basic_op];
    }
    else {
        my $non_basic_op = ($opcode >> 4) & 0x3f;

        $self->{value1}     = ($opcode >> 10) & 0x3f;
        $self->{value2}     = undef;
        $self->{current_op} = $self->{non_basic_opcode_map}[$non_basic_op];
    }

    die "Illegal opcode" unless $self->{current_op};

    return STATE_READ_ARG_1;
}

sub _parse_value {
    my $self = shift;
    my ($value) = @_;

    my $state = $self->{state};
    my $key = $state == STATE_READ_ARG_1 ? 'value1' : 'value2';

    if ($value < 0x08) {
        $self->{$key} = $self->{registers}[$value];
        $self->{lvalue} = \$self->{registers}[$value]
            if $state == STATE_READ_ARG_1;
    }
    elsif ($value < 0x10) {
        my $addr = $self->{registers}[$value & 0x07];
        $self->{$key} = $self->{memory}[$addr];
    }
    elsif ($value < 0x18) {
        $self->_next_word;
        return $state if $self->{time_taken} != TIME_TAKEN_WORK;

        my $addr = $self->{registers}[$value & 0x07] + $self->{next_word};
        $self->{$key} = $self->{memory}[$addr];
        $self->{lvalue} = \$self->{memory}[$addr]
            if $state == STATE_READ_ARG_1;
    }
    elsif ($value > 0x1f) {
        die "Illegal value" unless $value <= 0x3f;
        $self->{$key} = $value - 0x20;
    }
    elsif ($value == 0x18) {
        $self->{$key} = $self->{memory}[($self->{SP}++ & 0xffff)];
        $self->{SP} &= 0xffff;
    }
    elsif ($value == 0x19) {
        $self->{$key} = $self->{memory}[$self->{SP}];
    }
    elsif ($value == 0x1a) {
        $self->{$key} = $self->{memory}[(--$self->{SP} & 0xffff)];
        $self->{SP} &= 0xffff;
    }
    elsif ($value == 0x1b) {
        $self->{$key} = $self->{SP};
        $self->{lvalue} = \$self->{SP}
            if $state == STATE_READ_ARG_1;
    }
    elsif ($value == 0x1c) {
        $self->{$key} = $self->{PC};
        $self->{lvalue} = \$self->{PC}
            if $state == STATE_READ_ARG_1;
    }
    elsif ($value == 0x1d) {
        $self->{$key} = $self->{O};
    }
    elsif ($value == 0x1e) {
        $self->_next_word;
        return $state if $self->{time_taken} != TIME_TAKEN_WORK;

        my $addr = $self->{next_word};
        $self->{$key} = $self->{memory}[$addr];
        $self->{lvalue} = \$self->{memory}[$addr]
            if $state == STATE_READ_ARG_1;
    }
    elsif ($value == 0x1f) {
        $self->_next_word;
        return $state if $self->{time_taken} != TIME_TAKEN_WORK;

        $self->{$key} = $self->{next_word};
    }

    return $state == STATE_READ_ARG_2 || !defined($self->{value2})
        ? STATE_OP_EXECUTE
        : STATE_READ_ARG_2;
}

sub _execute_current_op {
    my $self = shift;

    my $op_meth = $self->{current_op};
    $self->$op_meth($self->{value1}, $self->{value2});

    return $self->{state} if $self->{time_taken} != TIME_TAKEN_WORK;

    $self->{lvalue} = undef;

    return STATE_NEW_OP;
}

sub _next_word {
    my $self = shift;

    undef $self->{next_word};

    return 1 if $self->_delay(1);

    $self->{next_word} = $self->{memory}[$self->{PC}++];

    return;
}

sub _delay {
    my $self = shift;
    my ($delay) = @_;

    return unless $delay;

    $delay--;

    if (!$delay || $self->{has_delayed}) {
        $self->{time_taken} = TIME_TAKEN_WORK;
        undef $self->{has_delayed};
        return;
    }
    else {
        $self->{time_taken} = TIME_TAKEN_DELAY;
        $self->{delay} = $delay - 1;
        $self->{has_delayed} = 1;
        return 1;
    }
}

sub _op_SET {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(1);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    ${ $self->{lvalue} } = $b;
}

sub _op_ADD {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(2);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a + $b;
    $self->{O} = $$lvalue >> 16;
    $$lvalue &= 0xffff;
}

sub _op_SUB {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(2);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a - $b;
    $self->{O} = $$lvalue >> 16;
    $$lvalue &= 0xffff;
}

sub _op_MUL {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(2);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a * $b;
    $self->{O} = $$lvalue >> 16;
    $$lvalue &= 0xffff;
}

sub _op_DIV {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(3);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    if ($b == 0) {
        $$lvalue = 0;
        $self->{O} = 0;
    }
    else {
        $$lvalue = $a / $b;
        $self->{O} = (($a << 16) / $b) & 0xffff;
        $$lvalue &= 0xffff;
    }
}

sub _op_MOD {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(3);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    if ($b == 0) {
        $$lvalue = 0;
    }
    else {
        $$lvalue = ($a % $b) & 0xffff;
    }
}

sub _op_SHL {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(2);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a << $b;
    $self->{O} = $$lvalue >> 16;
    $$lvalue &= 0xffff;
}

sub _op_SHR {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(2);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a >> $b;
    $self->{O} = (($a << 16) >> $b) & 0xffff;
    $$lvalue &= 0xffff;
}

sub _op_AND {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(1);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a & $b;
}

sub _op_BOR {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(1);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a | $b;
}

sub _op_XOR {
    my $self = shift;
    my ($a, $b) = @_;

    return if $self->_delay(1);

    my $lvalue = $self->{lvalue};
    return unless $lvalue;

    $$lvalue = $a ^ $b;
}

sub _op_IFE {
    my $self = shift;
    my ($a, $b) = @_;

    if ($a == $b) {
        return if $self->_delay(2);
    }
    else {
        return if $self->_delay(3);

        $self->{PC} += $self->_op_length;
    }
}

sub _op_IFN {
    my $self = shift;
    my ($a, $b) = @_;

    if ($a != $b) {
        return if $self->_delay(2);
    }
    else {
        return if $self->_delay(3);

        $self->{PC} += $self->_op_length;
    }
}

sub _op_IFG {
    my $self = shift;
    my ($a, $b) = @_;

    if ($a > $b) {
        return if $self->_delay(2);
    }
    else {
        return if $self->_delay(3);

        $self->{PC} += $self->_op_length;
    }
}

sub _op_IFB {
    my $self = shift;
    my ($a, $b) = @_;

    if ($a & $b) {
        return if $self->_delay(2);
    }
    else {
        return if $self->_delay(3);

        $self->{PC} += $self->_op_length;
    }
}

sub _op_JSR {
    my $self = shift;
    my ($a) = @_;

    return if $self->_delay(2);

    $self->{memory}[(--$self->{SP} & 0xffff)] = $self->{PC};
    $self->{SP} &= 0xffff;
    $self->{PC} = $a;
}

sub _op_HLT {
    my $self = shift;
    my ($a) = @_;

    $self->{halt} = 1;
}

=for notes

behavior of MOD?

behavior of underflow?

how do you do only a PUSH? POP and PEEK make sense as values, PUSH doesn't

is PC incremented for success of the test ops during execution of the test op,
or before execution of the next op? really, when is PC incremented in general?

does memory start out as 0, or undefined?

what happens when an invalid op is read?

=cut

1;
