Copyright 2023 (C) Peter McGoron.

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in `doc/copying` in the Upsilon 
source distribution.

__________________________________________________________________________

* The control loop is inflexible and poorly documented.
* Waveform modules might be necessary but are untested.

# Coptic: Upsilon 2.0

Coptic is an improved architecture for Upsilon.

Coptic would have multiple RV32EM CPUs (configurable at build time) that
run independently of the main Linux CPU. Along with the main RAM segment
the Linux CPU can access block RAM segments which run independently of
system RAM.

The Linux CPU can

* Allocate main RAM segments to a CPU for rw access
* Allocate entire BRAM blocks to a CPU
* Receive interrupts from CPUs
* Send interrupts to CPUs
* Start CPUs, halt CPUs, reset CPUs
