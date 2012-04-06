package Games::Emulation::DCPU16::Util;
use strict;
use warnings;

use Exporter 'import';

our @EXPORT_OK = ('format_registers', 'format_memory');

sub format_registers {
    my ($registers, $sp, $pc, $o) = @_;

    return join("\n",
        sprintf("A:  0x%04x    X:  0x%04x    I:  0x%04x",
                $registers->[0], $registers->[3], $registers->[6]),
        sprintf("B:  0x%04x    Y:  0x%04x    J:  0x%04x",
                $registers->[1], $registers->[4], $registers->[7]),
        sprintf("C:  0x%04x    Z:  0x%04x",
                $registers->[2], $registers->[5]),
        "",
        sprintf("SP: 0x%04x    PC: 0x%04x    O:  0x%04x", $sp, $pc, $o),
        "",
    );
}

sub format_memory {
    my ($memory) = @_;

    my $out = '';
    my $eliding = 0;
    for my $addr (0..int(@$memory / 8)) {
        $addr *= 8;
        my @values = @{ $memory }[$addr..($addr + 7)];
        if (grep { $_ } @values) {
            $out .= sprintf("%04x:" . (" %04x" x 8), $addr, @values) . "\n";
            $eliding = 0;
        }
        else {
            if (!$eliding) {
                $out .= "...\n";
                $eliding = 1;
            }
        }
    }

    return $out;
}

1;
