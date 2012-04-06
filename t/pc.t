#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Games::Emulation::DCPU16;

=begin assembly_code

  SET [0x0002],PC

=end assembly_code

=cut

{
    my $cpu = Games::Emulation::DCPU16->new;
    $cpu->load("\x71\xe1\x00\x02");

    $cpu->step; # load 0x0002

    is_deeply(
        $cpu->memory,
        [
            0x71e1, 0x0002,
            (0) x (0x10000 - 2)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 1);

    $cpu->step; # execute SET [0x0002], PC

    is_deeply(
        $cpu->memory,
        [
            0x71e1, 0x0002,
            (0) x (0x10000 - 2)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0002);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 2);
}

=begin assembly_code

        SET [0x0006], 0x02
  :loop SET [0x0007], PC
        SET PC, loop

=end assembly_code

=cut

{
    my $cpu = Games::Emulation::DCPU16->new;
    $cpu->load("\x89\xe1\x00\x06\x71\xe1\x00\x07\x7d\xc1\x00\x02");

    $cpu->step; # load 0x0006

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002,
            (0) x (0x10000 - 6)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 1);

    $cpu->step; # execute SET [0x0006], 0x02

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002,
            (0) x (0x10000 - 7)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0002);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 2);

    $cpu->step; # load 0x0007

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002,
            (0) x (0x10000 - 7)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0002);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 3);

    $cpu->step; # execute SET [0x0007], PC

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0004);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 4);

    $cpu->step; # load 0x0002

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0004);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 5);

    $cpu->step; # execute SET [0x0007], PC

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0002);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 6);

    $cpu->step; # load 0x0007

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0002);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 7);

    $cpu->step; # execute SET [0x0007], PC

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0004);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 8);

    $cpu->step; # load 0x0002

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0004);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 9);

    $cpu->step; # execute SET [0x0007], PC

    is_deeply(
        $cpu->memory,
        [
            0x89e1, 0x0006, 0x71e1, 0x0007, 0x7dc1, 0x0002, 0x0002, 0x0002,
            (0) x (0x10000 - 8)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0002);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 10);
}

=begin assembly_code

  :loop SET PC, loop

=end assembly_code

=cut

{
    my $cpu = Games::Emulation::DCPU16->new;
    $cpu->load("\x7d\xc1\x00\x00");

    $cpu->step; # load 0x0000

    is_deeply(
        $cpu->memory,
        [
            0x7dc1,
            (0) x (0x10000 - 1)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 1);

    $cpu->step; # execute SET PC, loop

    is_deeply(
        $cpu->memory,
        [
            0x7dc1,
            (0) x (0x10000 - 1)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 2);

    $cpu->step; # load 0x0000

    is_deeply(
        $cpu->memory,
        [
            0x7dc1,
            (0) x (0x10000 - 1)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 3);

    $cpu->step; # execute SET PC, loop

    is_deeply(
        $cpu->memory,
        [
            0x7dc1,
            (0) x (0x10000 - 1)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 4);

    $cpu->step; # load 0x0000

    is_deeply(
        $cpu->memory,
        [
            0x7dc1,
            (0) x (0x10000 - 1)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 5);

    $cpu->step; # execute SET PC, loop

    is_deeply(
        $cpu->memory,
        [
            0x7dc1,
            (0) x (0x10000 - 1)
        ]
    );
    is_deeply(
        $cpu->registers,
        [ (0x0000) x 8 ],
    );
    is($cpu->PC, 0x0000);
    is($cpu->SP, 0x0000);
    is($cpu->O,  0x0000);
    is($cpu->clock, 6);
}

done_testing;
