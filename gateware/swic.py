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
 
     def __init__(self, masters_len, slave):
         """
         :param masters_len: The amount of buses accessing this slave. This number
           must be greater than one.
         :param slave: The slave device. This object must have an Interface object
           accessable as ``bus``.
         """
 
         assert masters_len > 1
         self.buses = []
         self.master_select = CSRStorage(masters_len, name='master_select', description='RW bitstring of which master interconnect to connect to')
         self.slave = slave
 
         for i in range(masters_len):
             # Add the slave interface each master interconnect sees.
             self.buses.append(Interface(data_width=32, address_width=32, addressing="byte"))
 
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
 
        self.bus = Interface(data_width = 32, address_width = 32, addressing="word")
        self.width = 0x20
        self.sync += [
                If(self.bus.cyc == 1 and self.bus.stb == 1 and self.bus.ack == 0,
                    Case(self.bus.adr[0:4], {
                        0x0: self.bus.dat_r.eq(self.cl_I.storage),
                        0x4: self.bus.dat_r.eq(self.cl_P.storage),
                        0x8: self.bus.dat_r.eq(self.deltaT.storage),
                        0xC: self.bus.dat_r.eq(self.setpt.storage),
                        0x10: If(self.bus.we,
                                self.zset.status.eq(self.bus.dat_w)
                            ).Else(
                                self.bus.dat_r.eq(self.zset.status)
                            ),
                        0x14: If(self.bus.we,
                                self.zpos.status.eq(self.bus.dat_w),
                            ).Else(
                                self.bus.dat_r.eq(self.zpos.status)
                            ),
                        "default": self.bus.dat_r.eq(0xdeadbeef),
                    }),
                    self.bus.ack.eq(1),
                ).Else(
                    self.bus.ack.eq(0),
                )
        ]

class PicoRV32(LiteXModule, MemoryMap):
    def add_params(self, origin):
        params = ControlLoopParameters()
        self.add_module("params", params)
        self.add_region('params', BasicRegion(origin, params.width, params.bus))

    def __init__(self, name, start_addr=0x10000, irq_addr=0x10010):
        MemoryMap.__init__(self)
        self.name = name

        self.masterbus = Interface(data_width=32, address_width=32, addressing="byte")

        self.resetpin = CSRStorage(1, name="enable", description="PicoRV32 enable")

        self.trap = CSRStatus(8, name="trap", description="Trap condition")
        self.d_adr = CSRStatus(32)
        self.d_dat_w = CSRStatus(32)
        self.dbg_insn_addr = CSRStatus(32)
        self.dbg_insn_opcode = CSRStatus(32)

        self.comb += [
                self.d_adr.status.eq(self.masterbus.adr),
                self.d_dat_w.status.eq(self.masterbus.dat_w),
        ]

        # NOTE: need to compile to these extact instructions
        self.specials += Instance("picorv32_wb",
            p_COMPRESSED_ISA = 1,
            p_ENABLE_MUL = 1,
            p_PROGADDR_RESET=start_addr,
            p_PROGADDR_IRQ  =irq_addr,
            p_REGS_INIT_ZERO = 1,
            o_trap = self.trap.status,

            i_wb_rst_i = ~self.resetpin.storage,
            i_wb_clk_i = ClockSignal(),
            o_wbm_adr_o = self.masterbus.adr,
            o_wbm_dat_o = self.masterbus.dat_w,
            i_wbm_dat_i = self.masterbus.dat_r,
            o_wbm_we_o = self.masterbus.we,
            o_wbm_sel_o = self.masterbus.sel,
            o_wbm_stb_o = self.masterbus.stb,
            i_wbm_ack_i = self.masterbus.ack,
            o_wbm_cyc_o = self.masterbus.cyc,

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
            o_debug_state = Signal(2),

            o_dbg_insn_addr = self.dbg_insn_addr.status,
            o_dbg_insn_opcode = self.dbg_insn_opcode.status,
        )

    def do_finalize(self):
        self.dump_mmap(self.name + ".json")
        self.submodules.decoder = self.bus_submodule(self.masterbus)
