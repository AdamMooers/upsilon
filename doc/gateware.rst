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

===================
System Architecture
===================

Upsilon uses a RISC-V CPU running Linux to power most operations. It currently
uses a single-core VexRISC-V CPU running mainline Linux 5.x. How the main core
communicates with the hardware is a software issue: see /doc/software.rst .

Basic configuration of the SoC is done in the /gateware/config.py file. If this
file does not exist, copy /gateware/config.py.def to /gateware/config.py .
This is the default config.

The **main CPU** is the VexRISC-V core running Linux. All other CPUs or bus
masters can be overridden by this main CPU. To avoid confusion, "master" is
used when referring to something that is the master of the Wishbone bus: other
CPUs besides the main CPU are masters, even though their actions are
subordinated by the main CPU.

------------
Wishbone Bus
------------

The bus on all CPUs is the Wishbone bus. The Wishbone bus is a relatively simple
yet powerful master-slave architecture. For this project each bus has one master
and multiple slaves, but each slave can connect to multiple buses (and hence,
multiple masters).

All of the Wishbone bus lines are connected directly to the master with the
exception of the ``cyc`` signal. The ``cyc`` signal indicates that the master
has selected that slave device for a transfer. The ``stb`` signal will then
go up (sometimes at the same time) to indicate that there is valid data on all
other bus lines of interest. The bus master waits until ``ack`` is asserted.

The main CPU has a timeout on the Wishbone bus, but other CPUs may not. This
is to simplify interconnect logic from a programming perspective.

-------------------------
The Wishbone Bus in LiteX
-------------------------

Each master and slave has a Wishbone bus ``Interface`` (under
``litex.soc.interconnect.wishbone``). To make it, do::

    self.bus = Interface(data_width=32, address_width=32, addressing="byte")
 
The bus is always going to be 32 bit and will always be transmitting 32 bit
words. The reason for ``addressing="byte"`` will be discussed in the next
section.

The basic structure of the bus handling code is::

    self.sync += [
        If(self.bus.cyc & self.bus.stb & ~self.bus.ack,
            Case(self.bus.adr[0:length], ...),
            self.bus.ack.eq(1)
        ).Else(~self.bus.cyc,
            self.bus.ack.eq(0)
        )
    ]

``length`` is the length in bits that the bus code should look at. Since the
region could be anywhere in memory, the slave should never look at the entire
address (except for debugging purposes). Most of the time::

    length = self.width.bit_length()

Note that Migen differs from Verilog, since all indexing is LSB-first and the
last index is excluded. Hence ``adr[0:length]`` is equivalent to ``adr[length-1:0]``
in generated Verilog.

-----------------------------------
Rules For Writing Wishbone Bus Code
-----------------------------------

The Main CPU is word-addressed. It only reads at 32-bit word boundaries, and
will specify sub-word-unit writes using ``sel``. When a *bus* is
word-addressed, that means it expects addresses to be words. For instance,
``0x0`` is word 0, ``0x1`` is word 1, etc.

Since this is confusing, **all Upsilon Wishbone bus code must be byte
addressed.** This means that ``0x0`` is byte 0 of word 0 (little endian),
``0x1`` is byte 1 of word 1, etc. and ``0x4`` is byte 0 of word 1.  Even though
all masters and slaves must be byte-addressed, they are not required to handle
misaligned accesses. **Upsilon slaves can assume that all accesses are
word-aligned,** but they should give sane errors on misaligned access.

The only masters and slaves that are word-addressed are the ones that are
from LiteX itself. Those have special code to convert to the byte-addressed
masters/slaves.

If the slave has one bus, it **must** be an attribute called ``bus``.

Each class that is accessed by a wishbone bus **must** have an attribute
called ``width`` that is the size, in bytes, of the region. This must be a power
of 2 (exception: wrappers around slaves since they might wrap LiteX slaves
that don't have ``width`` attributes).

Each class **should** have a attribute ``public_registers`` that is a dictionary,
keys are names of the register shown to the programmer and

1. ``origin``: offset of the register in memory
2. ``size``: size of the register in bytes (multiple of 4)

are required attributes. Other attributes are ``rw``, ``direction``, that are
explained in /doc/controller_manual.rst .

-----------------------------
Adding Slaves to the Main CPU
-----------------------------

After adding a module with an ``Interface``, the interface is connected to
to main CPU bus by calling one of two functions.

If the slave region has no special areas in it, call::

    self.bus.add_slave(name, slave.bus, SoCRegion(origin=None, size=slave.width, cached=False)

If the slave region has registers, add::

    self.add_slave_with_registers(name, iface, SoCRegion(...), slave.public_registers)

where the SoCRegion parameters are the same as before. Each slave device
should have a ``slave.width`` and a ``slave.public_registers`` attribute,
unless noted. Some slaves have only one bus, some have multiple.

The Wishbone cache is very confusing and causes custom Wishbone bus code to
not work properly. Since a lot of this memory is volatile you should never
enable the cache (possible exception: SRAM).

---------------------------------------------------------
Working Around LiteX using pre_finalize and mmio_closures
---------------------------------------------------------

LiteX runs code prior to calling ``finalize()``, such as CSR allocation,
that makes it very difficult to write procedural code without preallocating
lengths.

Upsilon solves this with an ugly hack called ``pre_finalize``, which runs at
the end of the SoC main module instantiation. All pre_finalize functions are
put into a list which is run with no arguments and with their return result
ignored.

``pre_finalize`` calls are usually due to ``PreemptiveInterface``, which uses
CSR registers.

There is another ugly hack, ``mmio_closures``, which is used to generate the
``mmio.py`` library. The ``mmio.py`` library groups together relevant memory
regions and registers into instances of MicroPython classes. The only good
way to do this is to generate the code for ``mmio.py`` at instantiation time,
but the origin of each memory region is not known at instantiation time. The
functions have to be delayed until after memory locations are allocated, but
there is no hook in LiteX to do that, and the only interface I can think of
that one can use to look at the origins is ``csr.json``.

The solution is a list of closures that return strings that will be put into
``mmio.py``. They take one argument, ``csrs``, the ``csr.json`` file as a
Python dictionary. The closures use the memory location origin in ``csrs``
to generate code with the correct offsets.

Note that the ``csr.json`` file casefolds the memory locations into lowercase
but keeps CSR registers as-is.

====================
System Within a Chip
====================

A *system within a chip* (SWiC) is a SoC within a SoC. Upsilon has the
capability to add SWiCs that can be controlled by the main CPU.  The CPU for
the SWiC is the PicoRV32, which is a RISC-V RV32IMC core (RISC-V, 32 bit,
standard registers, multiplication, and compressed instructions).

The main CPU controls the SWiC through a special memory region on the Wishbone
bus. (Currently there are CSRs, but I consider this a hack and they will be
removed.) There are three ways the main CPU interacts with the SWiC:

1. Direct control. The main CPU can start and reset the SWiC CPU. It can
   also inspect the SWiC CPU's registers and program counter.
2. Exclusive registers. Small data can be transfered in the Main -> SWiC and
   SWiC -> Main direction using *Special Registers*. They are small registers
   that can be read by both CPUs but only one CPU can write to them.  This is
   used for sending parameters to programs without having to recompile them.
3. *Preemptive Interfaces* (PI), which connect a Wishbone slave to two or more
   Wishbone buses. Only one bus has read-write access to the slave at any time.
   The main CPU controls bus access. In the future, both read and write access
   can be modified, instead of the both or neither.

As an example of PI, the SWiC RAM is behind a PI. The main CPU resets the SWiC
(through direct control), fills the SWiC with machine code, fills the exclusive
registers with values, and then starts the SWiC CPU. External communiciation
(such as SPI) is through PI.

---------------------------------
Adding Memory Regions to the SWiC
---------------------------------

PicoRV32 uses a byte-addressed bus. However, it looks like it will not attempt
non-word aligned accesses. Slaves written for the main CPU will work with the SWiC,
and vice-versa.

The processing for connecting a Wishbone slave to the PicoRV32 bus is slightly
different because the usual LiteX code interferes with the build process (LiteX
only expects one Wishbone bus). The code for managing the SWiC bus is in
/gateware/region.py .

To add an ``Interface`` called ``iface``::

    pico.mmap.add_region(name, BasicRegion(origin=origin, size=iface.width, bus=iface))

Note that unlike in the main CPU, the origin of the region must be specified.
The origin does not have to be a power of 2 but must have enough zero bits
to completely store ``iface.width`` bytes.

=====================
Workarounds and Hacks
=====================

---------------------------------------------
LiteX Compile Times Take Too Long for Testing
---------------------------------------------

Set ``compile_software`` to ``False`` in ``soc.py`` when checking for Verilog
compile errors. Set it back when you do an actual compile run, or your program
will not boot.

If LiteX complains about not having a RiscV compiler, that is because your
system does not have compatible RISC-V compiler in your ``$PATH``.  Refer to
the LiteX install instructions above to see how to set up the SiFive GCC, which
will work.

----------------------------------
F4PGA Crashes When Using Block RAM
----------------------------------

This is really a Yosys (and really, an abc bug). F4PGA defaults to using
the ABC flow, which can break, especially for block RAM. To fix, edit out
``-abc`` in the tcl script (find it before you install it...)

This is mitigated by using ``SRAM`` in LiteX directly, which seems to
magically work.

-------------------------------------------------------------
Modules Simulate Correctly, but Don't Work at All in Hardware
-------------------------------------------------------------

Yosys fails to calculate computed parameter values correctly. For instance,

    parameter CTRLVAL = 5;
    localparam VALUE = CTRLVAL + 1;

Yosys will *silently* fail to compile this, setting `VALUE` to be equal
to 0. The solution is to use macros.

This also seems to magically work in PicoRV32. This may work if ``localparam
integer`` is used instead.

---------------------
Reset Pins Don't Work
---------------------

On the Arty A7 there is a Reset button. This is connected to the CPU and only
resets the CPU. Possibly due to timing issues modules get screwed up if they
share a reset pin with the CPU. The code currently connects button 0 to reset
the modules seperately from the CPU.

-------------------------
Verilog Macros Don't Work
-------------------------

Verilog's preprocessor is awful. F4PGA (through yosys) barely supports it.

You should only use Verilog macros as a replacement for ``localparam``.
When you need to do so, you must preprocess the file with
Verilator. For example, if you have a file called ``mod.v`` in the folder
``firmware/rtl/mod/``, then in the file ``firmware/rtl/mod/Makefile`` add

    codegen: [...] mod_preprocessed.v

(putting it after all other generated files). The file
``firmware/rtl/common.makefile`` should automatically generate the
preprocessed file for you.

If your Verilog is complex enough to need generation, consider writing
it in Migen instead.

-------------------------
RAM Check failure on Boot
-------------------------

This is most likely a bus issue. You might have overloaded the CSR bus. Move
some CSRs to a wishbone bus module. This can also happen due to timing errors
across the main CPU bus, which should be alleviated by reducing combinational
circuits and using registers through it.

--------------------------------------------------
Accesses to a Wishbone bus memory area do not work
--------------------------------------------------

Try reading 16 words (64 bytes) into the memory area and see if the
behavior changes. Many times this is due to the Wishbone Cache interfering
with volatile memory. Set the `cached` parameter in the SoCRegion to
`False` when adding the slave.

---------------------
Migen Recursion Error
---------------------

You passed the wrong value (like a string) where Migen expected a statement
or a value. For instance, instead of an assignment statement, you instead put a
string indiciating the value you want to assign.

---------------------
Sources Missing Error
---------------------

LiteX build will stop after creating the module tree. This  is because you
imported a module that does not exist. LiteX will silently fail if a Verilog
source file you added does not exist, so either remove the module or add the
file.

---------------------------------------------
I overrode finalize and now things are broken
---------------------------------------------

*Never* override the ``finalize()`` function in a Migen module.

Each Migen module has a ``finalize()`` function inherited from the class. This
does code generation and calls ``do_finalize()``, which is a user-defined
function.

=========
TODO List
=========

Pseudo CSR bus for the main CPU?
