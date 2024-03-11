# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from migen import *
from litex.soc.interconnect.wishbone import Decoder, Interface
from litex.gen import LiteXModule

from util import *

"""
LiteX has an automatic Wishbone bus generator that has a lot of quality of life
features, like overlap checking, relocation, multiple masters, etc.

It doesn't work when the main SoC bus is also using the bus generator, so this
module implements a basic Wishbone bus generator. All locations have to be
added manually and there is no sanity checking.
"""

class Register:
    """ Register describes a register in a memory region. It must have an
        origin and a bit width.

        Register stores all fields as attributes.
    """
    def __init__(self, origin, bitwidth, **kwargs):
        self.origin = origin
        self.bitwidth = bitwidth

        # Assign all values in kwargs as attributes.
        self.__dict__.update(kwargs)

    def _to_dict(self):
        """ This function has an underscore in front of it in order
            for it to not get picked up in this comprehension. """
        return {k: getattr(self,k) for k in dir(self) if not k.startswith("_")}

class BasicRegion:
    """ Simple class for storing a RAM region. """
    def __init__(self, origin, size, bus=None, registers=None):
        """
        :param origin: Positive integer denoting the start location
           of the memory region.
        :param size: Size of the memory region. This must be of the form
           (2**N - 1).
        :param bus: Instance of a wishbone bus interface.
        :param registers: Dictionary where keys are names of addressable
          areas in the region, values are instances of Register.
        """

        self.origin = origin
        self.size = size
        self.bus = bus
        self.registers = registers

    def decoder(self):
        """
        Wishbone decoder generator. The decoder looks at the high
        bits of the address to check what bits are passed to the
        slave device.

        Examples:

        Location 0x10000 has 0xFFFF of address space.
        origin = 0x10000, rightbits = 16.

        Location 0x10000 has 0xFFF of address space.
        origin = 0x10000, rightbits = 12.

        Location 0x100000 has 0x1F of address space.
        origin = 0x100000, rightbits = 5.
        """
        rightbits = minbits(self.size-1)
        print(self.origin, self.origin >> rightbits)
        return lambda addr: addr[rightbits:32] == (self.origin >> rightbits)

    def to_dict(self):
        return {
                "origin" : self.origin,
                "width": self.size,
                "registers": {k:v._to_dict() for k,v in self.registers.items()}
                             if self.registers is not None else None
        }

    def __str__(self):
        return str(self.to_dict())

class MemoryMap(LiteXModule):
    """ Stores the memory map of an embedded core. """
    def __init__(self, masterbus):
        self.regions = {}
        self.masterbus = masterbus

    def add_region(self, name, region):
        assert name not in self.regions
        self.regions[name] = region

    def dump_mmap(self, jsonfile):
        with open(jsonfile, 'wt') as f:
            import json
            json.dump({k : self.regions[k].to_dict() for k in self.regions}, f)

    def adapt(self, target_bus):
        """
        When a slave is "word" addressed (like SRAM), it accepts an index
        into a array with 32-bit elements. It DOES NOT accept a byte index.
        When a byte-addressed master (like the CPU) interacts with a word
        addressed slave, there must be an adapter in between that converts
        between the two.
        
        PicoRV32 will read the word that contains a byte/halfword and
        extract the word from it (see code assigning mem_rdata_word).
        """
        assert target_bus.addressing in ["byte", "word"]
        if target_bus.addressing == "byte":
            return target_bus
        adapter = Interface(data_width=32, address_width=32, addressing="byte")

        self.comb += [
                target_bus.adr.eq(adapter.adr >> 2),
                target_bus.dat_w.eq(adapter.dat_w),
                target_bus.we.eq(adapter.we),
                target_bus.sel.eq(adapter.sel),
                target_bus.cyc.eq(adapter.cyc),
                target_bus.stb.eq(adapter.stb),
                target_bus.cti.eq(adapter.cti),
                target_bus.bte.eq(adapter.bte),
                adapter.ack.eq(target_bus.ack),
                adapter.dat_r.eq(target_bus.dat_r),
        ]

        return adapter

    def do_finalize(self):
        slaves = [(self.regions[n].decoder(), self.adapt(self.regions[n].bus))
                for n in self.regions]
        # TODO: timeout using InterconnectShared?
        self.submodules.decoder = Decoder(self.masterbus, slaves, register=True)
 
class PeekPokeInterface(LiteXModule):
    """ Module that exposes registers to two Wishbone masters.
        Registers can be written to by at most one CPU. Some of them are
        read-only for both.

        NOTE: The interface only accepts up to 32 bit registers and does not
        respect wstrb. All writes will be interpreted as word writes.
    """

    def __init__(self):
        self.firstbus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.secondbus = Interface(data_width = 32, address_width = 32, addressing="byte")

        # If an address is added, this is the next memory location
        self.next_register_loc = 0

        # Register description
        self.public_registers = {}

        # Migen signals
        self.signals = {}

        self.has_pre_finalize = False

    def mmio(self, origin):
        r = ""
        for name, reg in self.public_registers.items():
            can_write = True if reg.can_write == "1" else False
            r += f'{name} = Register(loc={origin + reg.origin}, bitwidth={reg.bitwidth}, rw={can_write}),'
        return r

    def add_register(self, name, can_write, bitwidth, sig=None):
        """ Add a register to the memory area.

        :param name: Name of the register in the description.
        :param bitwidth: Width of the register in bits.
        :param can_write: Which CPU can write to it. One of "1", "2" or
           empty (none).
        """

        if self.has_pre_finalize:
            raise Exception("Cannot add register after pre finalization")

        if sig is None:
            sig = Signal(bitwidth)

        if name in self.public_registers:
            raise NameError(f"Register {name} already allocated")

        self.public_registers[name] = Register(
            origin=self.next_register_loc,
            bitwidth=bitwidth,
            can_write=can_write,
        )

        self.signals[name] = sig

        # Each location is padded in memory space to 32 bits.
        # Push every 32 bits to a new memory location.
        while bitwidth > 0:
            self.next_register_loc += 0x4
            bitwidth -= 32

    def pre_finalize(self):
        second_case = {"default": self.secondbus.dat_r.eq(0xFACADE)}
        first_case = {"default": self.firstbus.dat_r.eq(0xEDACAF)}

        if self.has_pre_finalize:
            raise Exception("Cannot pre_finalize twice")
        self.has_pre_finalize = True

        for name in self.public_registers:
            sig = self.signals[name]
            reg = self.public_registers[name]

            if reg.bitwidth > 32:
                raise Exception("Registers larger than 32 bits are not supported")

            def write_case(bus):
                return If(bus.we,
                            sig.eq(bus.dat_w),
                        ).Else(
                            bus.dat_r.eq(sig)
                        )
            def read_case(bus):
                return bus.dat_r.eq(sig)

            if reg.can_write == "2":
                second_case[reg.origin] = write_case(self.secondbus)
                first_case[reg.origin] = read_case(self.firstbus)
            elif reg.can_write == "1":
                second_case[reg.origin] = read_case(self.secondbus)
                first_case[reg.origin] = write_case(self.firstbus)
            elif reg.can_write == "":
                second_case[reg.origin] = read_case(self.secondbus)
                first_case[reg.origin] = read_case(self.firstbus)
            else:
                raise Exception("Invalid can_write: ", reg.can_write)

        self.width = round_up_to_pow_2(self.next_register_loc)

        # The width is a power of 2 (0b1000...). This bitlen is the
        # number of bits to read, starting from 0.
        bitlen = (self.width - 1).bit_length()

        def bus_logic(bus, cases):
            self.sync += If(bus.cyc & bus.stb & ~bus.ack,
                            Case(bus.adr[0:bitlen], cases),
                            bus.ack.eq(1)
                    ).Elif(~bus.cyc,
                            bus.ack.eq(0))

        bus_logic(self.firstbus, first_case)
        bus_logic(self.secondbus, second_case)

    def do_finalize(self):
        if not self.has_pre_finalize:
            raise Exception("pre_finalize required")
