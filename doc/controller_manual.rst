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

Example::

    import machine
    from mmio import *
    machine.mem32[pico0_dbg_reg]

This reads the first register from ``pico0_dbg_reg``.

-------------------
Accessing Registers
-------------------

At the lowest level, a program will write to and read from "registers" which
are mapped to memory. These registers control the operations of various parts
of the system.

The main bus has two register buses: "CSR" (which is the LiteX default), and
custom Wishbone code. CSR register information is in the ``csr.json`` file.
Wishbone bus registers are allocated with regions that are specified in
``csr.json``, while the actual registers inside that region are located in
``soc_subregions.json``. These should be automatically dumped to the Micropython
file ``mmio.py`` for easy usage.

``csr.json`` is not that well documented and can change from version to version
of LiteX.

``soc_subregions.json`` is a JSON object where the keys denote ``memories`` in
``csr.json``. If the object of that key is ``null``, then that region is
uniform (e.g. it is RAM, which is one continuous block). The objects of each of
these are registers that reside in the memory region. The keys of the registers
are

1. ``origin``: offset of the register from the beginning of the memory.
2. ``bitwidth``: Size of the register in bits. Right now cannot be more than ``32``.
   even if the writable space is smaller. Always access with words.
3. ``rw``: True if writable and False if not. Sometimes this is not there
   because the writable might be dynamic or must be inferred from other
   properties.
4. ``direction``: For registers inside a ``PeekPokeInterface``, ``1`` for
   writable by the Main CPU, ``2`` for writable by SWiC, and blank for read-only.

``pico0.json`` (and other PicoRV32 JSON files) are JSON objects whose keys are
memory regions. Their values are objects with keys:

1. ``origin``: Absolute position of the memory region.
2. ``bitwidth``: Width of the memory region in bits.
3. ``registers``: Either ``null`` (uniform region, like above), or an object
   whose keys are the names of registers in the region. The values of these
   keys have the same interpretation as ``soc_subregions.json`` above.

A read only register is not necessarily constant!

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

----------------------------
Compiling and Executing Code
----------------------------

There is a Makefile in /swic/ that contains the commands to compile a source
file (with start function ``_start``) to a binary file without static variables
or RO data.

Each CPU has a header file (for example ``pico0_mmio.h`` that contains the
offsets where each word-sized register can be accessed.

If there is only program code (no RODATA, static variables, etc.) then you can
dump the ``.text`` section using objdump (this requires a RISC-V compiler
installed, 64 bit is fine). Afterwards the data can be loaded by writing each
byte into the RAM section (the start of the ram section in the main CPU
corresponds to ``0x10000`` on the SWiC).

More advanced options would require more advanced linker script knowledge.

----------------
Complete Example
----------------

The compiler can be accessed in the docker container, you can also install it
under Ubuntu.

I haven't tested this yet, but this is how the code should work::

    #include "pico0_mmio.h"

    void _start(void) {
        uint32_t i = 0;

        for (;;) {
            *DAC0_TO_SLAVE = i;
            *DAC0_ARM = 1;
            while (*!DAC_FINISHED_OR_READY);

            i += *DAC_FROM_SLAVE;
            *DAC0_ARM = 0;
        }
    }

This code does reads and writes to registers defined in ``pico0_mmio.h``.
This file in this example is saved as ``test.c``.

To compile it use::

    riscv64-unknown-elf-gcc \
      -march=rv32imc \
      -mabi=ilp32 \
      -ffreestanding \
      -nostdlib \
      -Os \
      -Wl,-build-id=none,-Bstatic,-T,riscv.ld,--strip-debug \
      -nostartfiles \
      -lgcc \
      test.c -o test.elf

In order:

1. ``-march=rv32imc`` compiles for RISC-V, 32 bit registers, multiplication,
   and compressed instructions.
2. ``-mabi=ilp32`` compiles for the 32 bit ABI without floating pint.
3. ``-ffreestanding`` compiles as "Freestanding C" <https://en.cppreference.com/w/c/language/conformance>.
4. ``-Os`` means "optimize for size."
5. ``-Wl`` introduces linker commands, I don't know how the linker works.
6. ``-nostartfiles`` does not include the default ``_start`` in the binary.
7. ``-lgcc`` links the base GCC library, which is used for builtins (I think).
8. ``test.c -o test.elf`` compiles the C file and outputs it to ``test.elf``.

The resulting ELF can be inspected using ``riscv64-unknown-elf-objdump`` (look up
the instructions). To copy the machine code to ``test.bin``, execute::

    riscv64-unknown-elf-objcopy -O binary -j .text test.elf test.bin

The standard library has ``load()`` as a method for each PicoRV32 instance.

First import the SoC memory locations::

    from mmio import *

Then load the file (the file needs to be uploaded to the SoC)::

    pico0.load(filename)

Fill in any registers::

    pico0.regs.cl_I = 115200

Then run it::

    pico0.enable()

To inspect how the core is running, use dump::

    from pprint import pprint
    pprint(pico0.dump())

This will tell you about all the memory mapped registers, all the PicoRV32
registers, the program counter, etc. It also includes the ``trap`` condition,
which is an integer whose values are defined in ``picorv32.v``. ``0`` indicate
normal execution (or stopped).

================
Computer Control
================

Micropython code can be loaded manually with SSH but this gets cumbersome.
Python scripts on the controlling computer connected to the Upsilon FPGA can
upload, execute, and read data back from the FPGA automatically. The code that
does this is in /client/ . They don't work right now and need to be updated.

===
FAQ
===

------------------
SCP Is Not Working
------------------

SCP by default uses SFTP, which dropbear does not support. Pass `-O` to all
SCP invocations to use the legacy SCP protocol.
