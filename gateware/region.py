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
Python module implements a basic Wishbone bus generator. All locations have to be
added manually and there is no sanity checking.
"""

class Register:
    """ Register describes a register in a memory region. It must have an
        "origin" and a "bitwidth" field. Other fields might be used by different
        masters.

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
    """ Class for storing a RAM region, which may be filled with registers. """

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

class RegisterInterface(LiteXModule):
    """ 
    A single memory region filled with 32 bit registers. Each register
    can be read-write or read only.
    """

    def __init__(self):
        self.bus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.next_register_loc = 0
        self.public_registers = {}
        self.signals = {}
        self.has_pre_finalize = False
    
    @property
    def width(self):
        return round_up_to_pow_2(self.next_register_loc)

    def mmio(self, origin):
        """ 
        Returns a string that can be a keyword argument in Python
        that describes all registers in an instance of this module.
        """

        r = ""
        for name, reg in self.public_registers.items():
            r += f'{name} = Register(loc={origin + reg.origin}, bitwidth={reg.bitwidth}, rw={not reg.read_only}),'
        return r

    def add_register(self, name, read_only, bitwidth_or_sig):
        """
        :param name: name of the register
        :param read_only: True if register is read-only, False if register is read-write
        :param bitwidth_or_sig: Creates a new signal for the register if a width is given
            or uses the provided signal as the register
        """
        assert not self.has_pre_finalize

        if type(bitwidth_or_sig) is int:
            sig = Signal(bitwidth_or_sig)
        else:
            sig = bitwidth_or_sig
        
        bitwidth = sig.nbits

        assert bitwidth <= 32
        assert name not in self.public_registers

        self.public_registers[name] = Register(
            origin=self.next_register_loc,
            bitwidth=bitwidth,
            read_only = read_only
        )

        # Each location is padded in memory space to 32 bits.
        # Push every 32 bits to a new memory location.
        while bitwidth > 0:
            self.next_register_loc += 0x4
            bitwidth -= 32

        self.signals[name] = sig

    def add_registers(self, registers):
        """
        Often more than one register is created at a time. This method provides
        a clean way to add them in bulk.
        :param registers: A list of tuples containing the args to create the registers
        """
        for reg_args in registers:
            self.add_register(*reg_args)

    def pre_finalize(self):
        """ Loop through each register and build a Verilog case statement
            implementing the bus.

            NOTE: The interface only accepts up to 32 bit registers and
            does not respect wstrb. All writes will be interpreted as
            word writes.
        """
        assert not self.has_pre_finalize
        self.has_pre_finalize = True

        b = self.bus

        cases = {}
        for name in self.public_registers:
            sig = self.signals[name]
            reg = self.public_registers[name]

            # Format dat_r explicitly, padding out any 
            # unused bits with 0s
            dat_r_bits = [b.dat_r[0:sig.nbits].eq(sig)]
            if (sig.nbits < 32):
                dat_r_bits.append(b.dat_r[sig.nbits:].eq(0))


            if reg.read_only:
                cases[reg.origin] = dat_r_bits
            else:
                cases[reg.origin] = \
                    If(b.we,
                        sig.eq(b.dat_w[0:sig.nbits])
                    ).Else(
                        *dat_r_bits
                    )

        # The width is a power of 2 (0b1000...). This bitlen is the
        # number of bits to read, starting from 0.
        print("Next reg loc " + str(self.next_register_loc))
        bitlen = (self.width - 1).bit_length()
        self.sync += If(b.cyc & b.stb & ~b.ack,
                        Case(b.adr[0:bitlen], cases),
                        b.ack.eq(1)
                     ).Elif(~b.cyc,
                        b.ack.eq(0))
 
class PeekPokeInterface(LiteXModule):
    """ Module that exposes registers to two Wishbone masters.
        Registers can be written to by at most one CPU. Some of them are
        read-only for both.
    """

    def __init__(self):
        self.submodules.first = RegisterInterface()
        self.submodules.second = RegisterInterface()
    def mmio(self, origin):
        return self.first.mmio(origin)

    def add_register(self, name, can_write, bitwidth_or_sig):
        """ Add a register to the memory area.

        :param name: Name of the register in the description.
        :param can_write: Which CPU can write to it. One of "1", "2" or
           empty (none).
        :param bitwidth_or_sig: Width of the register in bits or pre-existing signal
        """

        first = self.get_module("first")
        second = self.get_module("second")

        if can_write == "1":
            first.add_register(name, False, bitwidth_or_sig)
            second.add_register(name, True, first.signals[name])
        elif can_write == "2":
            first.add_register(name, True, bitwidth_or_sig)
            second.add_register(name, False, first.signals[name])
        else:
            first.add_register(name, True, bitwidth_or_sig)
            second.add_register(name, True, first.signals[name])

        self.public_registers = first.public_registers
        self.signals = first.signals

    def pre_finalize(self):
        self.first.pre_finalize()
        self.second.pre_finalize()
        self.width = self.first.width

    def do_finalize(self):
        assert self.first.has_pre_finalize
        assert self.second.has_pre_finalize

class PreemptiveInterface(LiteXModule):
    """ A preemptive interface is a manually controlled Wishbone interface
    that stands between multiple masters (potentially interconnects) and a
    single slave. A master controls which master (or interconnect) has access
    to the slave. This is to avoid bus contention by having multiple buses.

    To use this module, instantiate it. Then connect the controlling master
    to ``self.buses[0]``. Connect the other masters to ``self.buses[1]``, etc.
    Since the buses are seperate, origins don't have to be the same, but the
    size of the region will be the same as the slave interface.
    """

    def __init__(self, slave_bus, addressing="word", name=None):
        """
        :param slave_bus: Instance of Wishbone.Interface that connects to the
          slave's bus.
        :param addressing: Addressing style of the slave. Default is "word". Note
          that masters may have to convert when selecting self.buses. This conversion
          is not done in this module.
        :param name: Name for debugging purposes.
        """

        self.slave_bus = slave_bus
        self.addressing=addressing
        self.buses = []
        self.name = name

        self.master_names = []

        self.pre_finalize_done = False

    def add_master(self, name):
        """ Adds a new master bus to the PI.

        :return: The interface to the bus.
        :param name: Name associated with this master.
        """
        if self.pre_finalize_done:
            raise Exception(self.name + ": Attempted to modify PreemptiveInterface after pre-finalize")

        self.master_names.append(name)

        iface = Interface(data_width=32, address_width=32, addressing=self.addressing)
        self.buses.append(iface)
        return iface

    def pre_finalize(self, dump_name):
        # NOTE: DUMB HACK! CSR bus logic is NOT generated when inserted at do_finalize time!
        if self.pre_finalize_done:
            raise Exception(self.name + ": Cannot pre-finalize twice")
        self.pre_finalize_done = True

        masters_len = len(self.buses)
        self.master_select = Signal(masters_len)

        # FIXME: Implement PreemptiveInterfaceController module to limit proliferation
        # of JSON files
        with open(dump_name, 'wt') as f:
            import json
            json.dump(self.master_names, f)
 
    def do_finalize(self):
        if not self.pre_finalize_done:
            raise Exception(self.name + ": PreemptiveInterface needs a manual call to pre_finalize()")

        masters_len = len(self.buses)
        if masters_len == 0:
            return None

        """
        Construct a combinatorial case statement. In verilog, the case
        statment would look like
 
           always @ (*) case (master_select)
              1: begin
                 // Assign slave to master 1,
                 // Assign all other masters to dummy ports
              end
              2: begin
                 // Assign slave to master 2,
                 // Assign all other masters to dummy ports
              end
              // more cases:
              default: begin
                 // assign slave to master 0
                 // Assign all other masters to dummy ports
              end
 
        Case statement is a dictionary, where each key is either the
        number to match or "default", which is the default case.

        Avoiding latches:
        Left hand sign (assignment) is always an input.
        """
 
        def assign_for_case(current_case):
           asn = [ ]
 
           for j in range(masters_len):
              if current_case == j:
                 """ Assign all inputs (for example, slave reads addr
                    from master) to outputs. """
                 asn += [
                    self.slave_bus.adr.eq(self.buses[j].adr),
                    self.slave_bus.dat_w.eq(self.buses[j].dat_w),
                    self.slave_bus.cyc.eq(self.buses[j].cyc),
                    self.slave_bus.stb.eq(self.buses[j].stb),
                    self.slave_bus.we.eq(self.buses[j].we),
                    self.slave_bus.sel.eq(self.buses[j].sel),
                    self.buses[j].dat_r.eq(self.slave_bus.dat_r),
                    self.buses[j].ack.eq(self.slave_bus.ack),
                 ]
              else:
                 """ Master bus will always read 0 when they are not
                    selected, and writes are ignored. They will still
                    get a response to avoid timeouts. """
                 asn += [
                    self.buses[j].dat_r.eq(0),
                    self.buses[j].ack.eq(self.buses[j].cyc & self.buses[j].stb),
                 ]
           return asn
 
        cases = {"default": assign_for_case(0)}
        # This loop only executes cases when there is more than one master.
        for i in range(1, masters_len):
           cases[i] = assign_for_case(i)
 
        # If there is only one case, just connect the two interfaces as usual.
        if masters_len == 1:
            self.comb += cases["default"]
        else:
            self.comb += Case(self.master_select, cases)