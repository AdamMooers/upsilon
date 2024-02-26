Copyright 2023 (C) Peter McGoron.

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in `doc/copying` in the Upsilon 
source distribution.

__________________________________________________________________________

The Hardware Maintenance Manual is an overview of the hardware (non-software)
parts of Upsilon.

# Crash Course in FPGAs

Upsilon runs on a Field Programmable Gate Array (FPGA). FPGAs are sets
of logic gates and other peripherals that can be changed by a computer.
FPGAs can implement CPUs, digital filters, and control code at a much
higher speed than a computer. The downside is that FPGAs are much more
difficult to program for.

A large part of Upsilon is written in Verilog. Verilog is a Hardware
Description Language (HDL), which is similar to a programming language
(such as C++ or Python).

The difference is, is that Verilog compiles to a *piece of hardware* that
deals with individual bits executing operations in sync with a clock. This
differs from a *piece of software*, which is a set of instructions that a
computer follows. Verilog is usually much less abstract than regular code.

Regular code is tested on the system in which it is run. Hardware,
on the other hand, is very difficult to test on the device that it
is actually running on. Hardware is usually *simulated*. This project
primarily simulates Verilog code using the program Verilator, where the
code that runs the simulation is written in C++.

Instead of strings, integers, and classes, the basic components of all
Verilog code is the wire and the register, which store bits (1 and 0).
Wires connect components together, and registers store data, in a similar
way to variables in software. Unlike usual programming languages, where
code executes one step at a time, most FPGA code runs at the tick of
a clock. Each block of code exceutes in parallel.

To compile Verilog to a format suitable for execution on an FPGA, you
*synthesize* the Verilog into a low-level format that uses the specific
resources of the FPGA you are using, and then you run a *place and route*
program to allocate resources on the FPGA to fit your design. Running
synthesis on its own can help you understand how much resources a module
uses. Place-and-route gives you *timing reports*, which tell you about
major design problems that outstrip the capabilities of the FPGA (or the
programs you are using). You should look up what "timing" on an FPGA is
and learn as much as you can about it, because it is an issue that does
not happen in standard software and can be very difficult to fix when
you run into it.

Once a bitstream is synthesized, it is loaded onto a FPGA through a cable
(for this project, openFPGALoader).

## Recommendations for Learners

Kishore Mishra. Advanced Chip Design.

[Gisselquist Technology][GT] is the best free online resource for FPGA
programming out there. These articles will help you understand how to
write *good* FPGA code, not just valid code.

[GT]: https://zipcpu.com/

Here are some exercises for you to ease yourself into FPGA programming.

* Write an FPGA program that implements addition without using the `+`
  operator. This program should add each number bit by bit, handling
  carried digits properly. This is called a *full adder*.
* Write an FPGA program that multiplies two signed integers together,
  without using the `*` operator.  The width of these integers should
  not be hard-coded: it should be easy to change. What you write in
  this is something that is actually a part of this project: see
  `boothmul.v`. You do not (and should not!) write it just like Upsilon
  has written it.
* Write an FPGA program that communicates over SPI. For simplicity,
  you only need to write it for a single SPI mode: look up on the internet
  for details. There is an SPI slave device in this repository that you
  can use to simulate an end for the SPI master you write, but you should
  write the SPI slave yourself. For bonus points, connect your SPI master
  to a real SPI device and confirm that your communication works.

For each of these exercises, follow the complete "Design Testing Process"
below. At the very least, write simulations and test your programs on
real hardware.

# Verilog Programming Guidelines

See also [Dan Gisselquist][1]'s rules for FPGA development.

[1]: https://zipcpu.com/blog/2017/08/21/rules-for-newbies.html

* Use free and open source IP only. IP must be compatible with *both* the
  GPL v3.0 and the CERN OHL-v2-S.
* Stick to Verilog 2005. F4PGA will accept SystemVerilog but yosys sometimes
  synthesizes it incorrectly.
* Do not use parameters that are calculated from other parameters (yosys
  will not parse them correctly). Use m4 macros instead.
* Do not use Verilog macros. Use m4.
* Do all code and test generation in Makefiles.
* Simulate *every* module, even the trivial ones using Verilator.
  Simulation must be simulatable with open-source software (Verilator is
  preferred, but Icarus Verilog and similar are fine). Put test code in the same
  directory as the Verilog module, unless the Verilog module is external.
* Synthesize and verify large modules independently on hardware using
  the LiteX SoC generator. Put the generator source code (along with
  the hardware test driver) in the repository.
* Write *only* synthesizable verilog (except for direct test-bench code), even
  for modules that will not be synthesized.
* Dump traces using `.fst` format.
* Use only one clock.
* Only transition on the *positive edge* of the *system clock*.
* Do not use asynchronous resets.
* Don't write Wishbone bus code in Verilog modules. LiteX automatically
  takes care of connecting modules together and assigning each register
  a memory location.
* Keep all Verilog as generic as possible.
* Always initialize registers.
* Rerun tests after every change to the module.

## Conventions

### Wires

* When specfying widths, include the total bit width and subtract 1 from it,
  even in cases where the bit width is constant. For example, to declare an
  8-bit register, write `reg [8-1:0] r1`.
* If a wire is active low, append `_L` to the end of the name.

### Parameters

* Parameters are always in all caps.
* Parameters ending in `_WID` are bit widths that do not have an associated
  number (eg DAC widths, input register sizes).
* Parameters ending in `_SIZ` are the amount of bits required to store a
  certain number. These parameters can be calculated using `floor(log2(number) + 1)`.
  For example,
    * `255` has a `SIZ` of 8 (8 bits are required to store 255).
    * `256` has a `SIZ` of 9
    * `254`, `253`, etc. have a `SIZ` of 8
    * `127` has a `SIZ` of 7

## Design Testing Process

### Simulation

When you write or modify a verilog module, the first thing you should do
is write/run a simulation of that module. A simulation of that module
should at the minimum compare the execution of the module with known
results (called "Ground truth testing"). A simulation should also consider
edge cases that you might overlook when writing Verilog.

For example, a module that multiplies two signed integers together should
have a simulation that sends the module many pairs of integers, taking
care to ensure that all possible permutations of sign are tested (i.e.
positive times positive, negative times positive, etc.) and also that
special-cases are handled (i.e. largest 32-bit integer multiplied by
largest negative 32-bit integer, multiplication by 0 and 1, etc.).

Writing simulation code is a very boring task, but you *must* do it.
Otherwise there is no way for you to check that

1. Your code does what you want it to do
2. Any changes you make to your code don't break it

If you find a bug that isn't covered by your simulation, make sure you
add that case to the simulation.

The file `firmware/rtl/testbench.hpp` contains a class that you should
use to organize individual tests. Make a derived class of `TB` and
use the `posedge()` function to encode what default actions your test
should take at every positive edge of the clock. Remember, in C++ each
action is blocking: there is no equivalent to the non-blocking `<=`.

If you have to do a lot of non-blocking code for your test, you
should write a Verilog wrapper for your test that implements
the non-blocking code. **Verilator only supports a subset of
non-synthesizable Verilog.  Unless you really need to, use synthesizable
Verilog only.** See `firmware/rtl/waveform/waveform_sim.v` and
`firmware/rtl/waveform/dma_sim.v` for an example of Verilog files only
used for tests.

### Test Synthesis

**Yosys only accepts a subset of Verilog. You might write a bunch of
code that Verilator will happily simulate but that will fail to go
through Yosys.**

Once you have simulated your design, you should use yosys to synthesize it.
This will allow you to understand how much and what resources the module
is taking up. To do this, you can put the follwing in a script file:

    read_verilog module_1.v
    read_verilog module_2.v
    ...
    read_verilog top_module.v
    synth_xilinx -flatten -nosrl -noclkbuf -nodsp -iopad -nowidelut
    write_verilog yosys_synth_output.v

and run `yosys -s scriptfile`. The options to `synth_xilinx` reflect
the current limitations that F4PGA has. The file `xc7.f4pga.tcl` that
F4PGA downloads is the complete synthesis script, read it to understand
the internals of what F4PGA does to compile your verilog.

### Test Compilation

I haven't been able to do this for most of this project. The basic idea
is to use `firmware/rtl/soc.py` to load only the module to test, and
to use LiteScope to write and read values from the module. For more
information, you can look at
[the boothmul test](https://software.mcgoron.com/peter/boothmul/src/branch/master/arty_test).

### Formal Verification

This isn't used for this project but it really should.

# LiteX and F4PGA

LiteX is a System on a Chip builder written in Python. It easily integrates
Verilog modules and large system components (CPU, RAM, Ethernet) into
a design using a Python script.

All code written for LiteX is in `gateware/soc.py`. Run this script to build
the gateware. If you need to add new modules, you can add them to the design
by modifying the `Base` and the `UpsilonSoC` class.

All the code that you need to understand in `soc.py` is heavily documented.
(If it's not, that means I don't understand it.)

F4PGA is an open source synthesis suite. LiteX handles F4PGA for you (most of
the time).

You should use the Dockerfiles included with upsilon. They are simple and are
pinned to the latest known stable version that can build Upsilon. If you really
want to install LiteX and F4PGA to your system, just follow the commands in
the docker files.

# Workarounds and Hacks

## LiteX Compile Times Take Too Long for Testing

Set `compile_software` to `False` in `soc.py` when checking for Verilog
compile errors. Set it back when you do an actual compile run, or your
program will not boot.

If LiteX complains about not having a RiscV compiler, that is because
your system does not have compatible RISC-V compiler in your `$PATH`.
Refer to the LiteX install instructions above to see how to set up the
SiFive GCC, which will work.

## F4PGA Crashes When Using Block RAM

This is really a Yosys (and really, an abc bug). F4PGA defaults to using
the ABC flow, which can break, especially for block RAM. To fix, edit out
`-abc` in the tcl script (find it before you install it...)

## Modules Simulate Correctly, but Don't Work at All in Hardware

Yosys fails to calculate computed parameter values correctly. For instance,

    parameter CTRLVAL = 5;
    localparam VALUE = CTRLVAL + 1;

Yosys will *silently* fail to compile this, setting `VALUE` to be equal
to 0. The solution is to use macros.

## Reset Pins Don't Work

On the Arty A7 there is a Reset button. This is connected to the CPU and only
resets the CPU. Possibly due to timing issues modules get screwed up if they
share a reset pin with the CPU. The code currently connects button 0 to reset
the modules seperately from the CPU.

## Verilog Macros Don't Work

Verilog's preprocessor is awful. F4PGA (through yosys) barely supports it.

You should only use Verilog macros as a replacement for `localparam`.
When you need to do so, you must preprocess the file with
Verilator. For example, if you have a file called `mod.v` in the folder
`firmware/rtl/mod/`, then in the file `firmware/rtl/mod/Makefile` add

    codegen: [...] mod_preprocessed.v

(putting it after all other generated files). The file
`firmware/rtl/common.makefile` should automatically generate the
preprocessed file for you.

Another alternative is to use GNU `m4`.

## RAM Check failure on boot

You might have overloaded the CSR bus. Move some CSRs to a wishbone
bus module. See /gateware/swic.py for some simple Wishbone bus examples.
This can also happen due to timing errors across the main CPU bus.

## Accesses to a Wishbone bus memory area do not work

Try reading 16 words (64 bytes) into the memory area and see if the
behavior changes. Many times this is due to the Wishbone Cache interfering
with volatile memory. Set the `cached` parameter in the SoCRegion to
`False` when adding the slave.
