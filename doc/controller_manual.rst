Copyright 2023-2024 (C) Peter McGoron.

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in `doc/copying` in the Upsilon 
source distribution.

*******************************

=============
Preqreuisites
=============

You must know basic Linux shell (change directories, edit files with `vi`)
and basic SSH usage (sftp, ssh).

I assume you know Python.

===========
Micropython
===========

MicroPython is a programming language that is very similar to Python. It is
stripped down and designed to run on very small devices. If you have written
Python, you will be able to use MicroPython without issue. If you are not
a hardcore Python programmer, you might not even notice a difference.

Everything you need to know is here <https://docs.micropython.org>.

-------------
Memory Access
-------------

The ``machine`` module contains arrays called ``mem8``, ``mem16``, and ``mem32``.
They are used to directly access memory locations on the main CPU bus. Note
that ``mem32`` accesses must be word aligned.

-------------------
Accessing Registers
-------------------

At the lowest level, a program will write to and read from "registers." These
registers control the operations of various parts of the system.

The main bus has two register buses: "CSR" (which is the LiteX default), and
custom Wishbone code. CSR register information is in the ``csr.json`` file.
Wishbone bus registers are allocated with regions that are specified in
``csr.json``, while the actual registers inside that region are located in
``soc_subregions.json``. These should be automatically dumped to the Micropython
file ``mmio.py`` for easy usage.

====================
System Within a Chip
====================

Systems Within a Chip (**SWiCs**) are CPUs that are controlled by the main CPU
but run seperately (they have their own registers, RAM, etc.) They can be
programmed and controlled through Micropython.

The SWiC is a RV32IMC core. Code for the SWiC needs to be compiled for a start
address of ``0x10000`` and a IRQ handler at ``0x10010``. The default length of
the SWiC region is ``0x1000`` bytes.

Each core is given the name ``pico0``, ``pico1``, etc. The regions of each CPU
are stored in ``pico0.json``, ``pico1.json``, etc. The system used to control
slave access to the CPU bus is a CSR (and should be in ``mmio.py``).

================
Computer Control
================

Micropython code can be loaded manually with SSH but this gets cumbersome.
Python scripts on the controlling computer connected to the Upsilon FPGA can
upload, execute, and read data back from the FPGA automatically. The code that
does this is in /client/ . This will be updated because of the recent structural
changes to Upsilon.

===
FAQ
===

------------------
SCP Is Not Working
------------------

SCP by default uses SFTP, which dropbear does not support. Pass `-O` to all
SCP invocations to use the legacy SCP protocol.
