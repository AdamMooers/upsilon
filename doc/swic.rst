Copyright 2024 (C) Peter McGoron.

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in ``doc/copying`` in the Upsilon 
source distribution.

***************************************************

====================
System Within a Chip
====================

A *system within a chip* (SWiC) is a SoC within a SoC. Upsilon has the
capability to add SWiCs that can be controlled by the main CPU.  The CPU for
the SWiC is the PicoRV32, which is a RISC-V RVI32 core with optional C, M
extensions and custom-made non-branching instructions.

----------------
Main CPU Control
----------------

The main CPU controls the SWiC using two methods:

1. LiteX CSR Registers. This is for simple things where the main CPU should
   have 100% control at all times, like starting and stopping the CPU.
2. *Preemptive interfaces* (PI), which sit in front of a Wishbone slave. The
   main CPU has a LiteX CSR register which selects the Wishbone master the
   Wishbone slave connects to.

In usual operation the SWiC RAM sits behind a PI. Before the SWiC starts, the
main CPU switches the PI to itself, fills the RAM with the program, and then
switches it back to the SWiC. When the SWiC starts, the SWiC has read-write
access to the RAM. PIs are also used for connecting to external IO (like SPI).

In the future, there will be master-read-slave-write interfaces to transfer
bulk memory from the SWiC to the main CPU (for instances, raster scanning).

See /gateware/soc.py for implementation notes. 
