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

class BasicRegion:
    """ Simple class for storing a RAM region. """
    def __init__(self, origin, size, bus=None):
        """
        :param origin: Positive integer denoting the start location
           of the memory region.
        :param size: Size of the memory region. This must be of the form
           (2**N - 1).
        :param bus: Instance of a wishbone bus interface.
        """

        self.origin = origin
        self.size = size
        self.bus = bus

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
        return {"origin" : self.origin, "size": self.size}

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
        self.submodules.decoder = Decoder(self.masterbus, slaves, register=True)
 
