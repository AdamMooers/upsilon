Copyright 2024 (C) Peter McGoron.

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in ``doc/copying`` in the Upsilon 
source distribution.

***************************************************

This manual describes the hardware portion of Upsilon.

===============
LiteX and Migen
===============

Migen is a library that generates Verilog using Python. It uses Python
objects and methods as a DSL within Python.

LiteX is a SoC generator using Migen. LiteX includes RAM, CPU, bus logic,
etc. LiteX is very powerful but not well documented.

================
System on a Chip
================

Upsilon uses a RISC-V CPU running Linux to power most operations. It currently
uses a single-core VexRISC-V CPU running mainline Linux 5.x. How the main core
communicates with the hardware is a software issue: see /doc/software.rst .

Basic configuration of the SoC is done in the /gateware/config.py file. If
this file does not exist, copy /gateware/config.py.def to /gateware/config.py .
This is the default config.
