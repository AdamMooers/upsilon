# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from migen import *
from litex.soc.interconnect.csr import CSRStorage, CSRStatus
from litex.soc.interconnect.wishbone import Interface, SRAM, Decoder
from litex.gen import LiteXModule
from region import *

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
 
     def __init__(self, masters_len, slave, addressing="word"):
         """
         :param masters_len: The amount of buses accessing this slave. This number
           must be greater than one.
         :param slave: The slave device. This object must have an Interface object
           accessable as ``bus``.
         :param addressing: Addressing style of the slave. Default is "word". Note
           that masters may have to convert when selecting self.buses.
         """
 
         assert masters_len > 1
         self.buses = []
         self.master_select = CSRStorage(masters_len, name='master_select', description='RW bitstring of which master interconnect to connect to')
         self.slave = slave
 
         for i in range(masters_len):
             # Add the slave interface each master interconnect sees.
             self.buses.append(Interface(data_width=32, address_width=32, addressing=addressing))
 
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
                         self.slave.bus.adr.eq(self.buses[j].adr),
                         self.slave.bus.dat_w.eq(self.buses[j].dat_w),
                         self.slave.bus.cyc.eq(self.buses[j].cyc),
                         self.slave.bus.stb.eq(self.buses[j].stb),
                         self.slave.bus.we.eq(self.buses[j].we),
                         self.slave.bus.sel.eq(self.buses[j].sel),
                         self.buses[j].dat_r.eq(self.slave.bus.dat_r),
                         self.buses[j].ack.eq(self.slave.bus.ack),
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
         for i in range(1, masters_len):
             cases[i] = assign_for_case(i)
 
         self.comb += Case(self.master_select.storage, cases)

class SpecialRegister:
    """ Special registers used for small bits of communiciation. """
    def __init__(self, name, direction, width):
        """
        :param name: Name of the register, seen in mmio.py.
        :param direction: One of "PR" (pico-read main-write) or "PW" (pico-write main-read).
        :param width: Width in bits, from 0 exclusive to 32 inclusive.
        """
        assert direction in ["PR", "PW"]
        assert 0 < width and width <= 32
        self.name = name
        self.direction = direction
        self.width = width

    def from_tuples(*tuples):
        return [SpecialRegister(*args) for args in tuples]

class RegisterInterface(LiteXModule):
    """ Defines "registers" that are either exclusively CPU-write Pico-read
    or CPU-read pico-write. These registers are stored as flip-flops. """
    def __init__(self, registers):
        """
        :param registers: List of instances of SpecialRegister.
        """

        self.picobus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.mainbus = Interface(data_width = 32, address_width = 32, addressing="byte")

        pico_case = {"default": self.picobus.dat_r.eq(0xFACADE)}
        main_case = {"default": self.picobus.dat_r.eq(0xEDACAF)}

        # Tuple list of (SpecialRegister, offset)
        self.registers = []

        for num, reg in enumerate(registers):
            self.registers.append((reg, num*0x4))

            # Round up the width of the stored signal to a multiple of 8.
            wid = round_up_to_word(reg.width)
            sig = Signal(wid)
            def make_write_case(target_bus):
                """ Function to handle write selection for ``target_bus``. """
                writes = []
                if wid >= 8:
                    writes.append(If(target_bus.sel[0],
                        sig[0:8].eq(target_bus.dat_w[0:8])))
                if wid >= 16:
                    writes.append(If(target_bus.sel[1],
                        sig[8:16].eq(target_bus.dat_w[8:16])))
                if wid >= 32:
                    writes.append(If(target_bus.sel[2],
                        sig[16:24].eq(target_bus.dat_w[16:24])))
                    writes.append(If(target_bus.sel[3],
                        sig[24:32].eq(target_bus.dat_w[24:32])))
                return writes

            if reg.direction == "PR":
                pico_case[num*4] = self.picobus.dat_r.eq(sig)
                main_case[num*4] = If(self.mainbus.we,
                        *make_write_case(self.mainbus)).Else(
                                self.mainbus.dat_r.eq(sig))
            else:
                main_case[num*4] = self.mainbus.dat_r.eq(sig)
                pico_case[num*4] = If(self.picobus.we,
                        *make_write_case(self.picobus)).Else(
                                self.picobus.dat_r.eq(sig))

        self.width = round_up_to_pow_2(len(registers)*0x4)
        # Since array indices are exclusive in python (unlike in Verilog),
        # use the bit length of the power of 2, not the bit length of the
        # maximum addressable value.
        bitlen = self.width.bit_length()
        def bus_logic(bus, cases):
            self.sync += If(bus.cyc & bus.stb & ~bus.ack,
                            Case(bus.adr[0:bitlen], cases),
                            bus.ack.eq(1)
                    ).Elif(~bus.cyc,
                            bus.ack.eq(0))

        bus_logic(self.mainbus, main_case)
        bus_logic(self.picobus, pico_case)

    def dump_json(self, filename):
        """ Dump description of offsets to JSON file. """
        d = {}
        for reg, off in self.registers:
            d[reg.name] = {
                    "width" : reg.width,
                    "direction" : reg.direction,
                    "offset": off
            }
            import json
            with open(filename, 'wt') as f:
                json.dump(d, f)

class RegisterRead(LiteXModule):
    """ Inspect PicoRV32 registers via Wishbone bus. """
    def __init__(self):
        self.regs = [Signal(32) for i in range(1,32)]
        self.bus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.width = 0x100

        cases = {"default": self.bus.dat_r.eq(0xdeaddead)}
        for i, reg in enumerate(self.regs):
            cases[i*0x4] = self.bus.dat_r.eq(reg)

        # CYC -> transfer in progress
        # STB -> data is valid on the input lines
        self.sync += [
                If(self.bus.cyc & self.bus.stb & ~self.bus.ack,
                    Case(self.bus.adr[0:7], cases),
                    self.bus.ack.eq(1),
                ).Elif(self.bus.cyc != 1,
                    self.bus.ack.eq(0)
                )
        ]

# Parts of this class come from LiteX.
#
# Copyright (c) 2016-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2018 Sergiusz Bazanski <q3k@q3k.org>
# Copyright (c) 2019 Antmicro <www.antmicro.com>
# Copyright (c) 2019 Tim 'mithro' Ansell <me@mith.ro>
# Copyright (c) 2018 William D. Jones <thor0505@comcast.net>
# SPDX-License-Identifier: BSD-2-Clause
class PicoRV32(LiteXModule):
    def add_cl_params(self, origin, dumpname):
        """ Add parameter region for control loop variables. Dumps the
        region information to a JSON file `dumpname`.

        :param origin: Origin of the region for the PicoRV32.
        :param dumpname: File to dump offsets within the region (common to
          both Pico and Main CPU).
        :return: Interface used by main cpu to control variables.
        """
        params = RegisterInterface(
                SpecialRegister.from_tuples(
                    ("cl_I", "PR", 32),
                    ("cl_P", "PR", 32),
                    ("deltaT", "PR", 32),
                    ("setpt", "PR", 32),
                    ("zset", "PW", 32),
                    ("zpos", "PW", 32),
                ))
        self.add_module("cl_params", params)
        self.mmap.add_region("cl_params", BasicRegion(origin, params.width, params.picobus))
        params.dump_json(dumpname)
        return params.mainbus

    def __init__(self, name, start_addr=0x10000, irq_addr=0x10010, stackaddr=0x100FF):
        self.name = name
        self.masterbus = Interface(data_width=32, address_width=32, addressing="byte")
        self.mmap = MemoryMap(self.masterbus)
        self.resetpin = CSRStorage(1, name="enable", description="PicoRV32 enable")

        self.trap = CSRStatus(8, name="trap", description="Trap condition")
        self.d_adr = CSRStatus(32)
        self.d_dat_w = CSRStatus(32)
        self.dbg_insn_addr = CSRStatus(32)
        self.dbg_insn_opcode = CSRStatus(32)

        self.debug_reg_read = RegisterRead()
        reg_args = {}
        for i in range(1,32):
            reg_args[f"o_dbg_reg_x{i}"] = self.debug_reg_read.regs[i-1]

        mem_valid = Signal()
        mem_instr = Signal()
        mem_ready = Signal()
        mem_addr  = Signal(32)
        mem_wdata = Signal(32)
        mem_wstrb = Signal(4)
        mem_rdata = Signal(32)

        self.comb += [
            self.masterbus.adr.eq(mem_addr),
            self.masterbus.dat_w.eq(mem_wdata),
            self.masterbus.we.eq(mem_wstrb != 0),
            self.masterbus.sel.eq(mem_wstrb),
            self.masterbus.cyc.eq(mem_valid),
            self.masterbus.stb.eq(mem_valid),
            self.masterbus.cti.eq(0),
            self.masterbus.bte.eq(0),
            mem_ready.eq(self.masterbus.ack),
            mem_rdata.eq(self.masterbus.dat_r),
        ]

        self.comb += [
                self.d_adr.status.eq(mem_addr),
                self.d_dat_w.status.eq(mem_wdata),
        ]

        # NOTE: need to compile to these extact instructions
        self.specials += Instance("picorv32",
            p_COMPRESSED_ISA = 1,
            p_ENABLE_MUL = 1,
            p_REGS_INIT_ZERO = 1,
            p_PROGADDR_RESET=start_addr,
            p_PROGADDR_IRQ  =irq_addr,
            p_STACKADDR = stackaddr,
            o_trap = self.trap.status,

            o_mem_valid = mem_valid,
            o_mem_instr = mem_instr,
            i_mem_ready = mem_ready,

            o_mem_addr  = mem_addr,
            o_mem_wdata = mem_wdata,
            o_mem_wstrb = mem_wstrb,
            i_mem_rdata = mem_rdata,

            i_clk = ClockSignal(),
            i_resetn = self.resetpin.storage,

            o_mem_la_read  = Signal(),
            o_mem_la_write = Signal(),
            o_mem_la_addr  = Signal(32),
            o_mem_la_wdata = Signal(32),
            o_mem_la_wstrb = Signal(4),

            o_pcpi_valid = Signal(),
            o_pcpi_insn = Signal(32),
            o_pcpi_rs1 = Signal(32),
            o_pcpi_rs2 = Signal(32),
            i_pcpi_wr = 0,
            i_pcpi_wait = 0,
            i_pcpi_rd = 0,
            i_pcpi_ready = 0,

            i_irq = 0,
            o_eoi = Signal(32),

            o_trace_valid = Signal(),
            o_trace_data = Signal(36),

            o_dbg_insn_addr = self.dbg_insn_addr.status,
            o_dbg_insn_opcode = self.dbg_insn_opcode.status,

            **reg_args
        )

    def do_finalize(self):
        self.mmap.dump_mmap(self.name + ".json")
        self.mmap.finalize()
