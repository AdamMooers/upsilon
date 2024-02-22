# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from migen import *
from litex.soc.interconnect.wishbone import Decoder

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

class MemoryMap:
    """ Stores the memory map of an embedded core. """
    def __init__(self):
        self.regions = {}

    def add_region(self, name, region):
        assert name not in self.regions
        self.regions[name] = region

    def dump_mmap(self, jsonfile):
        with open(jsonfile, 'wt') as f:
            import json
            json.dump({k : self.regions[k].to_dict() for k in self.regions}, f)

    def bus_submodule(self, masterbus):
        """ Return a module that decodes the masterbus into the
            slave devices according to their origin and start positions. """
        slaves = [(self.regions[n].decoder(), self.regions[n].bus)
                for n in self.regions]
        return Decoder(masterbus, slaves, register=False)
 
