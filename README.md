# DCPU-16 Emulator and Assembler #

Based on the specification [here](http://0x10c.com/doc/dcpu-16.txt).

Includes an extra instruction HLT which stops execution of the current program
(otherwise it will run forever unless you tell it to only execute a certain
number of operations).

## Emulator ##

`perl -Ilib bin/dcpu16-execute [--iterations <n>] [--dump <outfile>] <binary>`

Executes a DCPU-16 binary file. Runs until a HLT instruction is seen, unless
`--iterations` is specified, in which case it runs for that many clock cycles.
Produces a memory and register dump at the end in the file `./dcpu16.dump` (or
whatever file you specify with the `--dump` option).

## Assembler ##

`perl -Ilib bin/dcpu16-asm [--output <outfile>] <asm_file>`

Creates a DCPU-16 binary from an assembler file. Assembler syntax is so far
limited to the examples that are given in the specification. Output is written
to `./a.out`, or whatever filename is given in the `--output` option.
