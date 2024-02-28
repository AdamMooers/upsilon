# upsilon

Upsilon is a 100% free and open source STM/AFM controller for FPGAs running
Linux. Read [doc/copying/README.md](doc/copying/README.md) for license information.

## Quickstart

Read [doc/docker.md](doc/docker.md) to set up the Docker build environment.

## Project Organization

* [boot](boot/): This folder is the central place for all built files. This
  includes the kernel image, rootfs, gateware, etc. This directory also
  includes everything the TFTP server has to access.
* [build](build/): Docker build environment.
* [buildroot](buildroot/): Buildroot configuration files.
* [doc](doc/): Documentation.
* [doc/copying](doc/copying/): Licenses.
* [gateware](gateware/): FPGA source.
* [gateware/rtl](gateware/rtl/): Verilog sources.
* [gateware/rtl/spi](gateware/rtl/spi/): SPI code (from another repo)
* [linux](linux/): Software that runs on the controller.
* [opensbi](opensbi/): OpenSBI configuration files and source fragments.
* [swic](swic/): Code that runs on the PicoRV32 soft core.
