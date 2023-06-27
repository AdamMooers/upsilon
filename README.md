# upsilon

Upsilon is a 100% free and open source STM/AFM controller for FPGAs running
Linux. Read `doc/copying/README.md` for license information.

## Quickstart

Read `doc/copying/docker.md` to set up the Docker build environment.

## Project Organization

* `boot/`: This folder is the central place for all built files. This
  includes the kernel image, rootfs, gateware, etc. This directory also
  includes everything the TFTP server has to access.
* `build/`: Docker build environment.
* `buildroot/`: Buildroot configuration files.
* `doc/`: Documentation.
* `doc/copying`: Licenses.
* `gateware/`: FPGA source.
* `linux/`: Software that runs on the controller.
* `opensbi/`: OpenSBI configuration files and source fragments.
