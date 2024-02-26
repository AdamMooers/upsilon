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

Locations of interest are included as constants in the ``mmio`` module, which
is generated from memory map JSON files (``csr.json`` and others). At some
point there will be a standard library that wraps these accesses as functions.

----------------
Computer Control
----------------

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
