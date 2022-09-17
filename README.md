# upsilon

Upsilon is a 100% free and open source STM/AFM controller for FPGAs.

## Organization

The project is split into hardware (`firmware`), kernel (`software`),
and client software (`client`).

Hardware uses Verilog, LiteX and F4PGA to implement the Soft CPU (Risc-V),
hardware communication, PI control loop, image scanning, and tip autoapproach.

Kernel implements the network communication between the hardware and the
client software.

The client software receives and interprets data from the hardware.

## License

GNU GPL v3.0 or later. Other portions are dual licensed under the CERN
OHL-v2-S, or permissive licenses: please view all `COPYING` files for more
legal information.
