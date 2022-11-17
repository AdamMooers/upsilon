# Firmware

See also [Dan Gisselquist][1]'s rules for FPGA development.

[1]: https://zipcpu.com/blog/2017/08/21/rules-for-newbies.html

* Use free and open source IP only. IP must be compatible with *both* the
  GPL v3.0 and the CERN OHL-v2-S.
* Stick to Verilog 2005. F4PGA will accept SystemVerilog but yosys sometimes
  synthesizes it incorrectly.
* Do not use parameters that are calculated from other parameters (yosys
  will not parse them correctly). Use macros instead.
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

# Software

* Use free and open source libraries only. All libraries must be compatible
  with the GNU GPL v3.0.
* Do not dynamically allocate memory.
* Use the [SEI CERT C Coding Standard][2] as a guideline.
* Use the [Linux kernel style guide][3] as a guideline (many parts of it
  are not relevant for this project).
* Try to offload as much processing as possible to the computer.

[2]: https://wiki.sei.cmu.edu/confluence/display/c/SEI+CERT+C+Coding+Standard
[3]: https://www.kernel.org/doc/Documentation/process/coding-style.
