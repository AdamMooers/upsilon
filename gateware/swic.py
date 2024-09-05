# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

# XXX: PicoRV32 code only handles word-sized registers correctly. Memory
# registers made up of multiple words are not supported right now.

from migen import *
from litex.soc.interconnect.csr import CSRStorage, CSRStatus
from litex.soc.interconnect.wishbone import Interface, SRAM, Decoder
from litex.gen import LiteXModule
from region import *

def gen_pico_header(pico_name):
    """ Generate PicoRV32 C header for this CPU from JSON file. """
    import json
    with open(pico_name + "_mmio.h", "wt") as out:
        print('#pragma once', file=out)

        with open(pico_name + ".json") as f:
            js = json.load(f)

        for region in js:
            if js[region]["registers"] is None:
                continue
            origin = js[region]["origin"]
            for reg in js[region]["registers"]:
                macname = f"{region}_{reg}".upper()
                loc = origin + js[region]["registers"][reg]["origin"]
                print(f"#define {macname} (volatile uint32_t *)({loc})", file=out)

# Parts of this class come from LiteX.
#
# Copyright (c) 2016-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2018 Sergiusz Bazanski <q3k@q3k.org>
# Copyright (c) 2019 Antmicro <www.antmicro.com>
# Copyright (c) 2019 Tim 'mithro' Ansell <me@mith.ro>
# Copyright (c) 2018 William D. Jones <thor0505@comcast.net>
# SPDX-License-Identifier: BSD-2-Clause
class PicoRV32(LiteXModule):
    def add_cl_params(self):
        """ Add parameter region for control loop variables. Dumps the
        region information to a JSON file `dumpname`.
        """

        self.params.add_register("deltaT", "1", 32)
        self.params.add_register("zpos", "2", 32)

    def __init__(self, name, start_addr=0x10000, irq_addr=0x10010, stackaddr=0x100FF, param_origin=0x100000):
        self.name = name
        self.masterbus = Interface(data_width=32, address_width=32, addressing="byte")
        self.mmap = MemoryMap(self.masterbus)

        self.params = PeekPokeInterface()
        self.param_origin = param_origin

        self.params.add_register("enable", "1", 1)
        self.params.add_register("trap", "", 8)
        self.params.add_register("debug_adr", "", 32)
        self.params.add_register("dat_w", "", 32)
        self.params.add_register("pc", "", 32)
        self.params.add_register("opcode", "", 32)

        reg_args = {}
        for num, reg in enumerate(["ra", "sp", "gp", "tp", "t0", "t1", "t2",
                                   "s0_fp", "s1", "a0",
                                   "a1", "a2", "a3", "a4", "a5", "a6", "a7",
                                   "s2", "s3", "s4", "s5", "s6", "s7", "t3",
                                   "t4", "t5", "t6",], start=1):
            self.params.add_register(reg, "", 32)
            reg_args[f"o_dbg_reg_x{num}"] = self.params.signals[reg]

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
            self.params.signals["debug_adr"].eq(mem_addr),
            self.params.signals["dat_w"].eq(mem_wdata),
        ]

        self.specials += Instance("picorv32",
            p_COMPRESSED_ISA = 1,
            p_ENABLE_IRQ = 1,
            p_ENABLE_IRQ_TIMER = 1,
            p_ENABLE_FAST_MUL = 1,
            p_REGS_INIT_ZERO = 1,
            p_PROGADDR_RESET=start_addr,
            p_PROGADDR_IRQ  =irq_addr,
            p_STACKADDR = stackaddr,

            o_trap = self.params.signals["trap"],

            o_mem_valid = mem_valid,
            o_mem_instr = mem_instr,
            i_mem_ready = mem_ready,

            o_mem_addr  = mem_addr,
            o_mem_wdata = mem_wdata,
            o_mem_wstrb = mem_wstrb,
            i_mem_rdata = mem_rdata,

            i_clk = ClockSignal(),
            i_resetn = self.params.signals["enable"],

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

            o_dbg_insn_addr = self.params.signals["pc"],
            o_dbg_insn_opcode = self.params.signals["opcode"],

            **reg_args
        )

    def do_finalize(self):
        self.mmap.finalize()
        self.mmap.dump_mmap(self.name + ".json")
        gen_pico_header(self.name)
