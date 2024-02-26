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
     to the slave. This is to avoid bus contention by having multiple buses. """
 
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

#TODO: Generalize CSR stuff
class ControlLoopParameters(LiteXModule):
    """ Interface for the Linux CPU to write parameters to the CPU
        and for the CPU to write data back to the CPU without complex
        locking mechanisms.

        This is a hack and will be replaced later with a more general
        memory region.
    """
    def __init__(self):
        self.cl_I = CSRStorage(32, description='Integral parameter')
        self.cl_P = CSRStorage(32, description='Proportional parameter')
        self.deltaT = CSRStorage(32, description='Wait parameter')
        self.setpt = CSRStorage(32, description='Setpoint')
        self.zset = CSRStatus(32, description='Set Z position')
        self.zpos = CSRStatus(32, description='Measured Z position')
 
        self.bus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.width = 0x20
        self.comb += [
                self.bus.err.eq(0),
        ]

        self.did_write = CSRStatus(8)
        self.sync += [
                If(self.bus.cyc & self.bus.stb & ~self.bus.ack,
                    Case(self.bus.adr[0:4], {
                        0x0: self.bus.dat_r.eq(self.cl_I.storage),
                        0x4: self.bus.dat_r.eq(self.cl_P.storage),
                        0x8: self.bus.dat_r.eq(self.deltaT.storage),
                        0xC: self.bus.dat_r.eq(self.setpt.storage),
                        0x10: If(self.bus.we,
                                self.zset.status.eq(self.bus.dat_w),
                                self.did_write.status.eq(self.did_write.status + 1),
                            ).Else(
                                self.bus.dat_r.eq(self.zset.status)
                            ),
                        0x14: If(self.bus.we,
                                self.zpos.status.eq(self.bus.dat_w),
                            ).Else(
                                self.bus.dat_r.eq(self.zpos.status)
                            ),
                        "default": self.bus.dat_r.eq(0xdeadc0de),
                    }),
                    self.bus.ack.eq(1),
                ).Elif(~self.bus.cyc,
                    self.bus.ack.eq(0),
                )
        ]

class PicoRV32RegisterRead(LiteXModule):
    def __init__(self):
        self.regs = [Signal(32) for i in range(1,32)]
        self.bus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.width = 0x100

        cases = {"default": self.bus.dat_r.eq(0xdeaddead)}
        for i, reg in enumerate(self.regs):
            cases[i*0x4] = self.bus.dat_r.eq(reg)

        self.debug_addr = CSRStatus(32)
        self.debug_cntr = CSRStatus(16)

        # CYC -> transfer in progress
        # STB -> data is valid on the input lines
        self.sync += [
                If(self.bus.cyc & self.bus.stb & ~self.bus.ack,
                    Case(self.bus.adr[0:7], cases),
                    self.bus.ack.eq(1),
                    self.debug_addr.status.eq(self.bus.adr),
                    self.debug_cntr.status.eq(self.debug_cntr.status + 1),
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
    def add_params(self, origin):
        params = ControlLoopParameters()
        self.add_module("params", params)
        self.mmap.add_region('params', BasicRegion(origin, params.width, params.bus))

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

        self.debug_reg_read = PicoRV32RegisterRead()
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
