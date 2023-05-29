Upsilon Maintenance Manual. This document may be distributed under your choice
of the GNU GPL v3.0 (or any later version), or under the [CC BY-SA 4.0][CC].

[CC]: https://creativecommons.org/licenses/by-sa/4.0/legalcode

# Introduction

This document is aimed at maintainers of this software who are not
experienced programmers (in either software or hardware). Its goal is
to contain any pertinent information to the devlopment process of Upsilon.

This manual is (hopefully) modular enough that you can just skip to the
section you need without having to read the entire thing.

## Organization of the Project

Upsilon uses LiteX and ZephyrOS for it's FPGA code. LiteX generates HDL
and glues it together. It also forms the build system of the hardware
portion of Upsilon. ZephyrOS is the kernel portion, which deals with
communication between the computer that receives scan data and the
hardware that is executing the scan.

LiteX further uses F4PGA to compile the HDL code. F4PGA is primarily
made up of Yosys (synthesis) and nextpnr (place and route).

## Required Knowledge

This document is written under the assumption that you are using Linux.
You can make this work on other platforms but I don't know how to.

Verilog is critical for writing hardware. You should hopefully not have
to write much of it.

The kernel is written in C. This C is different than C you have written
before because it is running "freestanding."

The kernel uses Zephyr as the real-time operating system running the
code. Zephyr has very good documentation and a very readable code base,
go read it.

Tests are written in C++ and verilog. You will not have to write C++
unless you modify the Verilog files.

The macro processing language GNU m4 is used occasionally. You will
need to know how to use m4 if you modify the main `base.v.m4` file
(e.g. adding more software-accessable ports).

Python is used for the bytecode assembler, the bytecode itself, and
the SoC generator. The SoC generator uses a library called LiteX,
which in turn uses migen.
You do not need to know a lot about migen, but LiteX's documentation
is poor so you will need to know some migen in order to read the
code and understand how some modules work.

# Compile Process

Although each component uses a different build system, you can run everything
with
1. `make` (compile everything in this folder)
2. `make clean` (clean up all compiled files)

## Setting up the Toolchain

The toolchain is primarily designed around modern Linux. It may not work
properly on Windows or MacOS. If you have access to a computational
cluster (if you are at FSU physics, ask the Physics department) then
you should set up the toolchain on their servers. You will be able to
compile things on any computer with an internet connection.

### F4PGA

1. Clone [F4PGA](https://github.com/chipsalliance/f4pga) (if you want,
   checkout commit `b6c5fff`, but you should try checking out master
   first)
2. Run `scripts/prepare_environment.sh`. Note that you will need to change
   the environment variable `$F4PGA_INSTALL_DIR` if you do not have access
   to the default directory (which is root access).
3. Run `scripts/activate.sh`. If you run into problems, open the file and
   copy the `source` and `conda` commands manually into your terminal.
4. Install meson and ninja through pip.

All commands should be done in the conda environment.

### Zephyr OS

These instructions are based on [these][zephyr_getting_started], but the Zephyr
environment should be installed into the F4PGA conda environment,

[zephyr_getting_started]: https://docs.zephyrproject.org/latest/develop/getting_started/index.html

1. Run `pip3 install west`
2. Run
   ```
   west init $ZEPHYR_DIRECTORY/zephyrproject
   cd $ZEPHYR_DIRECTORY/zephyrproject
   west update
   west zephyr-export
   pip install -r ~/zephyrproject/zephyr/scripts/requirements.txt
   cd $ZEPHYR_DIRECTORY/zephyrproject
   wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.0/zephyr-sdk-0.16.0_linux-x86_64.tar.xz
   wget -O - https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.0/sha256.sum | shasum --check --ignore-missing
   tar xvf zephyr-sdk-0.16.0_linux-x86_64.tar.xz
   cd zephyr-sdk-0.16.0
   ./setup.sh
   ```

### LiteX

1. Download `litex_setup.py` from the [LiteX repository][litex_repo], Upsilon
   uses 2022.08 to some directory (don't put it in your home directory because
   there will be a bunch of downloaded repositories.
2. Run `litex_setup.py --init --install --user --tag 2022.08`
3. Download a GCC RISC-V cross compiler. If you have root access to the build
   machine, then you can probably install this with your package manager. Users
   of Ubuntu 14 can download the [sifive][sifive_gcc] GCC. Otherwise you will have
   to compile a cross compiler (`x86_64` host to RV32I target) manually.
4. Put the GCC RISC-V cross compiler in your `$PATH` variable.

[litex_repo]: https://github.com/enjoy-digital/litex
[sifive_gcc]: https://github.com/sifive/freedom-tools/releases

## FPGA Build System

Make sure F4PGA and a RISC-V GCC compiler are in your path. Then just go into
the `firmware` folder and run `make`. This should generate everything you need
and compile the software. The synthesis suite is single threaded. This will
take about 15-20 minutes on a good computer.

The FPGA firmware (aka gateware) build system is designed in a recursive
manner. That means that each directory has a Makefile that processes all the
files in the directory. There is a `common.makefile` in the `rtl/` directory
that is used when a rule (such as preprocessing a Verilog source file)
is used in multiple Makefiles.

For the Arty A7, the bitstream is `firmware/build/digilent_arty/gateware/digilent_arty.bit`.

## Software Build System

The software build system uses files that are generated by the FPGA compile
process. The number one reason why software won't work when loaded onto the
FPGA is because it is compiled for a different FPGA bitstream. If you have
an issue where software that you know should work does not, run `make clean`
in the FPGA build system and rebuild it from scratch.

This requires at least CMake 3.20.0 (you can install this using `conda`).
Afterwards just run `make` and everything should work. Everything is
managed by the `CMakeLists.txt` and the `prj.conf`, see the Zephyr OS
documentation.

The kernel is `/software/build/zephyr/zephyr.bin`

If you make a change to `CMakeLists.txt` or to `prj.conf`, run `make clean`
before `make`.

Make can run in parallel using `-j${NUMBER_OF_PROCESSORS}`. Add this to the
`buidl/zephyr/zephyr.bin` in `/software/Makefile` to makeyour builds faster.
Remove this argument when you are attemping to fix compile errors and warnings
(it will make the build output easier to read) but put it back when you fix
them.

# Loading the Software and Firmware

## Network Setup

You will need the FPGA and the controlling computer on the same wired
network. **DO NOT CONNECT THE FPGA TO A WIDE NETWORK. USE A PRIVATE LAN
THAT ONLY CONTAINS THE CONTROLLING COMPUTER AND THE FPGA. DO NOT ATTEMPT
TO CONNECT THE FPGA TO THE INTERNET.** The controlling computer can
still connect to the internet, but through another LAN port. The best
thing to do is to buy a USB to Ethernet adapter.

You will need some way to do DHCP. The best way is to use a router, but
a standard wireless router will not fly with any IT department because
of the security risk. You need to find a non-wireless router (like a
managed switch). You can even retrofit an old computer into a router
(just needs another ethernet port).

The default TFTP client connects to 192.168.1.50.

## Connecting to the FPGA Over USB

Connect to the FPGA over USB and run `litex_term /dev/ttyUSB1` (or whatever
connection it should be) and you should see the LiteX BIOS come up. 

## Loading the Firmware

Connect the FPGA to a computer using a Micro-USB to USB cable. Run
`openFPGALoader -c digilent digilent_arty.bit` to upload the firmware
(gateware) to the controller.

You can load the software using serial boot but this is very slow. The
better thing to do is to use TFTP boot, which goes over Ethernet.
**WHEN YOU RUN TFTP, DO NOT EXPOSE YOUR INTERFACE TO THE INTERNET
CONNECTED NETWORK INTERFACE. THIS IS A BIG SECURITY RISK. ONLY RUN
TFTP FOR THE AMOUNT OF TIME REQUIRED TO BOOT THE CONTROL SOFTWARE.**
You can read about how to setup a TFTP server on the [OpenWRT wiki][owrt_wiki].
On Linux, run

	dnsmasq -d --port=0 --enable-tftp --tftp-root=/path/to/firmware/directory --user=root --group=root --interface=$INTERFACE

Do not use `--tftp-no-blocksize`. The controller will only read the first
512 bytes of the kernel.

In the root of the TFTP server, have `boot.bin` be the kernel binary
(`zephyr.bin`).

[owrt_wiki]: https://openwrt.org/docs/guide-user/troubleshooting/tftpserver

# FPGA

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
the system clock in parallel.

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

## Recommendations to Learners

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

## Control and Status Registers in Hardware

LiteX uses "Control and Status Registers" (CSRs) to communicate between
the CPU and any Verilog modules. (RISC-V CPUs have something with the
same name, but Upsilon does not use that.)

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

# Software Programming

The "software" is the code written in C that runs on the FPGA. This
handles access to hardware components, running scripts sent by the
controlling computer, and sending information between the hardware and
the controlling computer.

## Crash Course in Multithreaded Programming

Each script (up to 32 by default, change by redefining a macro) runs in
a separate thread. This allows for multiple scripts to execute without
having to explicitly hand control from one component to another, but
since there is no defined execution path (one thread may execute before
or after another thread), the program must handle scripts attempting to
access the same component.

Upsilon handles multiple threads using

1. Mutexes
2. Thread Local Storage

Mutexes ("mutual exclusion") are objects that only allow for one thread
to access them at a time. When one thread locks a mutex, other threads
attempting to lock the mutex sleep until the thread unlocks the mutex.
After the thread that locked the mutex unlocks it, some other thread gets
the mutex.

Mutex management is important because if multiple threads attempt to
read or write to a converter at the same time, the scripts could deadlock,
requiring a hard reset of the system. (You could add manual deadlock
aborting by adding new commands that call `k_thread_abort`, as long as
all threads are not deadlocked. This is a hack but may be necessary.)

Each thread can lock the mutex as many times as it wants, but it must
unlock the mutex the same number of times. Thread local storage (the
`__thread` modifier) is used to count the number of times that each mutex
is locked by a thread. Since (as the name implies) TLS is thread-local,
there is no need to control access to it by mutexes: each thread gets
its own local version of the thread local variables.

The software has to count the number of recursive locks because when
the thread finally releases control of the mutex, another thread must
be able to access the hardware in a well defined state: it should not
attempt to write to hardware while the hardware is running (certain
specific exceptions apply). When the unlock routines (see for example
`waveform_release()`) reach the final unlock
(e.g. `waveform_locked[i] == 1`), the software waits for the hardware
to finish what its doing before unlocking.

The kernel implements "time-slicing", which means that each running
program executes in chunks. After each chunk is finished, another
program can execute. The amount of time for each thread is controlled
by `CONFIG_TIMESLICE_SIZE` in `prj.conf`. When executing critical code,
use `k_sched_lock` and `k_sched_unlock`.

TODO: Use `k_thread_time_slice_set` to implement an abort check for
threads.

## Crash Course in Network Programming

The kernel communicates with the controlling computer using a TCP/IP
connection. You should connect the controller and the computer to a
router and assign the kernel a static IP.

Each script that runs on the kernel is a separate connection. Each
connection runs on a separate thread, because each thread runs a Creole
interpreter.

TCP can usually detect when a connection breaks, but you should gracefully
shutdown all connections. Otherwise dead connections can hang around for
minutes at a time.

### Static IPs

The client and controller IPs are baked into the software *and firmware*
at build time. The software configuration is in `software/prj.conf`. The
firmware configuration is in `firmware/soc.py` (see `local_ip` and `remote_ip`
settings in `SoCCore`).

The controlling computer must have it's static IP on the interface connected
to the controller to be the same as `remote_ip`. By default this is `91.168.1.100`.

## Logging

TODO: Do logging via UDP?

Logging is done via UART. Connect the micro-USB slot to the controlling
computer to get debug output.

All you need to know is

* Use `LOG_WRN` for errors that you can recover from (i.e. closing a
  connection
* Use `LOG_ERR` for errors that are fatal and halt the firmware,
  requiring a reset
* Use `LOG_INF` for misc information (i.e. initialization completed,
  accepted connection, closing connection)
* Use `LOG_DBG` for debugging output

If you need debugging output, add a line of the form

	set_source_file_properties(src_file PROPERTIES COMPILE_FLAGS -DFILE_LOG_LEVEL=4

This will enable debugging output for this file only. Do not enable
debugging output for the entire system! This will make the debugging
output unusuable.

When you are done, set `4` to `3` in that line.

TODO: Ethernet debugging output.

## Control and Status Registers in Software

CSR read and write functions are generated by `/firmware/generate_csr_locations.py`.
You should not need to directly call `write` and `read` on raw addresses.
If you add a new CSR, add it to the generator script.

### Implementation Information

CSRs can be used in software by using `litex_write8`,
`litex_read16`, etc. In the Zephyr source, look at
`soc/riscv/litex-vexriscv/soc.h` for the complete implementation.
Also look at `include/zephyr/arch/common/sys_io.h` to see how these
functions are implemented.

Do not directly write to CSR ports without using `litex_writeN` and
`litex_readN`, and do not directly use `sys_io.h` functions. If you are
not careful you will not access the registers correctly and you will
crash the software.

# Controlling Computer

## Creole

Creole is the bytecode that the kernel runs. It is written using a
python library. It looks very similar to assembly, but is custom built
to make it easier to write direct assembly code.

Creole programs are the scripts run by the kernel to communicate with
hardware and send messages over Ethernet to the controlling computer.
Each creole program should do one thing: i.e. monitor an ADC, run
the raster scan, output waveforms, etc.

Creole programs should reserve the hardware modules (DAC, ADC, CLOOP,
waveforms) that they use explicitly. This makes your program faster
and less error prone.

Since the Creole assembler is a python library, you can use things
like Python format strings to automate production of Creole code. You
can also add virtual instructions (by directly modifying the library)
easily.

Creole has a concept of data blocks, assigned using the `DB` command.
These blocks are used for waveforms and for printing sets of data out
to the datastream.

Creole uses a [self-synchronizing code][ssc] to detect encoding and
transmission errors. This makes programs bigger, but you should not
write big Creole programs.

[ssc]: https://en.wikipedia.org/wiki/Self-synchronizing_code

The controlling computer sends a 16 bit little endian unsigned integer
(the size of the Creole program in bytes) followed by Creole bytecode.

# Hacks and Pitfalls

The open source software stack that Upsilon uses is novel and unstable.

## LiteX

Set `compile_software` to `False` in `soc.py` when checking for Verilog
compile errors. Set it back when you do an actual compile run, or your
program will not boot.

If LiteX complains about not having a RiscV compiler, that is because
your system does not have compatible RISC-V compiler in your `$PATH`.
Refer to the LiteX install instructions above to see how to set up the
SiFive GCC, which will work.

## F4PGA

This is really a Yosys (and really, an abc bug). F4PGA defaults to using
the ABC flow, which can break, especially for block RAM. To fix, edit out
`-abc` in the tcl script (find it before you install it...)

## Yosys

Yosys fails to calculate computed parameter values correctly. For instance,

    parameter CTRLVAL = 5;
    localparam VALUE = CTRLVAL + 1;

Yosys will *silently* fail to compile this, setting `VALUE` to be equal
to 0. The solution is to use macros.

## Reset Pins

On the Arty A7 there is a Reset button. This is connected to the CPU and only
resets the CPU. Possibly due to timing issues modules get screwed up if they
share a reset pin with the CPU. The code currently connects button 0 to reset
the modules seperately from the CPU.

## Clock Speeds

The output pins on the FPGA (except for the high speed PMOD outputs) cannot
switch fast enough to

## Macros

Verilog's preprocessor is awful. F4PGA (through yosys) barely supports it.

You should only use Verilog macros as a replacement for `localparam`.
When you need to do so, you must preprocess the file with
Verilator. For example, if you have a file called `mod.v` in the folder
`firmware/rtl/mod/`, then in the file `firmware/rtl/mod/Makefile` add

    codegen: [...] mod_preprocessed.v

(putting it after all other generated files). The file
`firmware/rtl/common.makefile` should automatically generate the
preprocessed file for you.

## If The Controlling Computer Cannot Connect to the Internet

When you connect your computer to the controller over Ethernet, your computer
may attempt to route all traffic over the controller network (since it is
wired) instead of another network (like a wireless network). This means that
your computer can't connect to the internet (or your connection is really slow).
If this happens to you on a Linux machine, you can change the routing table.

Run `route -n` (or `ip route` if this does not work) to print the routing table.
Find the entry named `default via [...] dev eth-interface`. This is the default route
for the ethernet device. Remove it using `ip route del default via [...] dev eth-interface`.

If the route keeps on reappearing, delete it and quickly enter
`ip route del default via [...] dev eth0 metric 65534`. This will make the
route the last priority.

## Getting The Correct IP for the Controlling Computer

Some routers can automatically assign IPs based on MAC address. If your computer
can do that, great. Otherwise you will need to configure your computer with a
static ip.

1. Remove your computer from the DHCP list that the router has.
2. Run `ip link set eth-interface up`.
3. Then run `ip addr` and run `ip addr del [ip] dev eth-interface` on
   each ip on the ethernet interface that is connected to the controller.
3. Run `ip addr add 192.168.1.100/24 dev eth-interface` (or whatever ip + subnet
   mask you need)
4. If `ip route` does not give a routing entry for `192.168.1.0/24`, run
   `ip route add 192.168.1.0/24 dev eth0 proto kernel scope link` (again,
   change depending on different situations)

This will use the static ip `192.168.1.100`, which is the default TFTP boot
IP.
