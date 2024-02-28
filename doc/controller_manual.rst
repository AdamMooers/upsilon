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
2. ``size``: Size of the register in bytes. Right now this is always ``4``,
   even if the writable space is smaller. Always access with words.
3. ``rw``: True if writable and False if not. Sometimes this is not there
   because the writable might be dynamic or must be inferred from other
   properties.
4. ``direction``: Specifcally for registers that are Main-write-Pico-read
   or Main-read-Pico-write. ``PR`` denotes Pico-read, ``PW`` denotes Pico-write.

``pico0.json`` (and other PicoRV32 JSON files) are JSON objects whose keys are
memory regions. Their values are objects with keys:

1. ``origin``: Absolute position of the memory region.
2. ``width``: Width of the memory region in bytes.
3. ``registers``: Either ``null`` (uniform region, like above), or an object
   whose keys are the names of registers in the region. The values of these
   keys have the same interpretation as ``soc_subregions.json`` above.

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

This code can now be loaded into the PicoRV32's ram. The next code sections
will be written in Micropython.

First include the Micropython MMIO locations::

    from mmio import *

Next import ``machine``. You will almost always need this library.::

    import machine

Next import the PicoRV32 standard library. (Currently it is hard-coded for pico0,
this might change if more CPUs are required.)::

    import picorv32

Next load the code into Micropython::

    with open('test.bin', 'rb') as f:
        prog = f.read()

This assumes that ``test.bin`` has been uploaded to the FPGA. We now turn off
the CPU and switch control of the RAM to the main CPU::

    machine.mem32[pico0_enable] = 0
    machine.mem32[pico0ram_iface_master_select] = 0

Both of these values default to ``0`` on startup.

Now the program can be loaded into the PicoRV32's ram::

    assert len(prog) < 0xFFF
    for offset, b in enumerate(prog, start=pico0_ram):
        machine.mem8[offset] = b

The first line of the code makes sure that the code will overflow from the
RAM region and write other parts of memory. (TODO: this is hardcoded, and
the size of the region should also be written to memory.)

The loop goes though each byte of the program and writes it to the RAM,
starting at the beginning of the RAM. ``enumerate`` is just a fancy Python way
of a for loop with an increasing counter.

As a sanity test, check that the program was written correctly::

    for i in range(len(prog)):
        assert machine.mem8[pico_ram + i] == prog[i]

This can detect overwrite errors (a write to a read-only area will silently
fail) and cache mismatch errors.

After the program is loaded, the CPU can finally be started::

    machine.mem32[pico0ram_iface_master_select] = 1
    assert machine.mem8[pico0_ram] == 0
    machine.mem32[pico0_enable] = 1

The first line switches control of the RAM to the PicoRV32. The second line
checks if the switch worked. If this line fails, most likely the preemptive
interface is not properly connected to the PicoRV32 (or my code is buggy).
The final line starts the CPU.

The state of the CPU can be inspected using ``picorv32.dump()``. This will
tell you if the CPU is in a trap state and what registers the CPU is currently
reading.

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
