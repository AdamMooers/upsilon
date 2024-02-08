"""
##########################################################################
# Portions of this file incorporate code licensed under the
# BSD 2-Clause License.
#
# Copyright (c) 2015-2019 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Antmicro <www.antmicro.com>
# Copyright (c) 2022 Victor Suarez Rovere <suarezvictor@gmail.com>
# BSD 2-Clause License
# 
# Copyright (c) Copyright 2012-2022 Enjoy-Digital.
# Copyright (c) Copyright 2012-2022 / LiteX-Hub community.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##########################################################################
# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
"""

# There is nothing fundamental about the Arty A7(35|100)T to this
# design, but another eval board will require some porting.
from migen import *
import litex_boards.platforms.digilent_arty as board_spec
from litex.soc.integration.builder import Builder
from litex.build.generic_platform import IOStandard, Pins, Subsignal
from litex.soc.integration.soc_core import SoCCore
from litex.soc.integration.soc import SoCRegion, SoCBusHandler, SoCIORegion
from litex.soc.cores.clock import S7PLL, S7IDELAYCTRL
from litex.soc.interconnect.csr import AutoCSR, Module, CSRStorage, CSRStatus
from litex.soc.interconnect.wishbone import Interface

from litedram.phy import s7ddrphy
from litedram.modules import MT41K128M16
from litedram.frontend.dma import LiteDRAMDMAReader
from liteeth.phy.mii import LiteEthPHYMII

from math import log2, floor

def minbits(n):
    """ Return the amount of bits necessary to store n. """
    return floor(log2(n) + 1)

"""
Keep this diagram up to date! This is the wiring diagram from the ADC to
the named Verilog pins.

Refer to `A7-constraints.xdc` for pin names.
DAC: SS MOSI MISO SCK
  0:  1    2    3   4 (PMOD A top, right to left)
  1:  1    2    3   4 (PMOD A bottom, right to left)
  2:  1    2    3   4 (PMOD B top, right to left)
  3:  0    1    2   3 (Analog header)
  4:  0    1    2   3 (PMOD C top, right to left)
  5:  4    5    6   8 (Analog header)
  6:  1    2    3   4 (PMOD D top, right to left)
  7:  1    2    3   4 (PMOD D bottom, right to left)


Outer chip header (C=CONV, K=SCK, D=SDO, XX=not connected)
26  27  28  29  30  31  32  33  34  35  36  37  38  39  40  41
C4  K4  D4  C5  K5  D5  XX  XX  C6  K6  D6  C7  K7  D7  XX  XX
C0  K0  D0  C1  K1  D1  XX  XX  C2  K2  D2  C3  K3  D3
0   1   2   3   4   5   6   7   8   9   10  11  12  13

The `io` list maps hardware pins to names used by the SoC
generator. These pins are then connected to Verilog modules.

If there is more than one pin in the Pins string, the resulting
name will be a vector of pins.
"""
io = [
#    ("differntial_output_low", 0, Pins("J17 J18 K15 J15 U14 V14 T13 U13 B6 E5 A3"), IOStandard("LVCMOS33")),
    ("dac_ss_L_0", 0, Pins("G13"), IOStandard("LVCMOS33")),
    ("dac_mosi_0", 0, Pins("B11"), IOStandard("LVCMOS33")),
    ("dac_miso_0", 0, Pins("A11"), IOStandard("LVCMOS33")),
    ("dac_sck_0", 0, Pins("D12"), IOStandard("LVCMOS33")),
#    ("dac_ss_L", 0, Pins("G13 D13 E15 F5 U12 D7 D4 E2"), IOStandard("LVCMOS33")),
#    ("dac_mosi", 0, Pins("B11 B18 E16 D8 V12 D5 D3 D2"), IOStandard("LVCMOS33")),
#    ("dac_miso", 0, Pins("A11 A18 D15 C7 V10 B7 F4 H2"), IOStandard("LVCMOS33")),
#    ("dac_sck", 0, Pins("D12 K16 C15 E7 V11 E6 F3 G2"), IOStandard("LVCMOS33")),
#    ("adc_conv", 0, Pins("V15 T11 N15 U18 U11 R10 R16 U17"), IOStandard("LVCMOS33")),
#    ("adc_sck", 0, Pins("U16 R12 M16 R17 V16 R11 N16 T18"), IOStandard("LVCMOS33")),
#    ("adc_sdo", 0, Pins("P14 T14 V17 P17 M13 R13 N14 R18"), IOStandard("LVCMOS33")),
    ("module_reset", 0, Pins("D9"), IOStandard("LVCMOS33")),
#    ("test_clock", 0, Pins("P18"), IOStandard("LVCMOS33"))
]

# class PreemptiveInterface(Module, AutoCSR):
#     """ A preemptive interface is a manually controlled Wishbone interface
#     that stands between multiple masters (potentially interconnects) and a
#     single slave. A master controls which master (or interconnect) has access
#     to the slave. This is to avoid bus contention by having multiple buses. """
# 
#     def __init__(self, masters_len, slave):
#         """
#         :param masters_len: The amount of buses accessing this slave. This number
#           must be greater than one.
#         :param slave: The slave device. This object must have an Interface object
#           accessable as ``bus``.
#         """
# 
#         assert masters_len > 1
#         self.buses = []
#         self.master_select = CSRStorage(masters_len, name='master_select', description='RW bitstring of which master interconnect to connect to')
#         self.slave = slave
# 
#         for i in range(masters_len):
#             # Add the slave interface each master interconnect sees.
#             self.buses.append(Interface(data_width=32, address_width=32, addressing="byte"))
# 
#         """
#         Construct a combinatorial case statement. In verilog, the if
#         statment would look like
# 
#             always @ (*) case (master_select)
#                 1: begin
#                     // Bus assignments...
#                 end
#                 2: begin
#                     // Bus assignments...
#                 end
#                 // more cases:
#                 default:
#                     // assign everything to master 0
#                 end
# 
#         The If statement in Migen (Python HDL) is an object with a method
#         called "ElseIf" and "Else", that return objects with the specified
#         case attached. Instead of directly writing an If statement into
#         the combinatorial block, the If statement is constructed in a
#         for loop.
# 
#         The "assign_for_case" function constructs the body of the If
#         statement. It assigns all output ports to avoid latches.
#         """
# 
#         def assign_for_case(i):
#             asn = [ ]
# 
#             for j in range(masters_len):
#                 asn += [
#                     self.buses[i].cyc.eq(self.slave.bus.cyc if i == j else 0),
#                     self.buses[i].stb.eq(self.slave.bus.stb if i == j else 0),
#                     self.buses[i].we.eq(self.slave.bus.we if i == j else 0),
#                     self.buses[i].sel.eq(self.slave.bus.sel if i == j else 0),
#                     self.buses[i].adr.eq(self.slave.bus.adr if i == j else 0),
#                     self.buses[i].dat_w.eq(self.slave.bus.dat_w if i == j else 0),
#                     self.buses[i].ack.eq(self.slave.bus.ack if i == j else 0),
#                     self.buses[i].dat_r.eq(self.slave.bus.dat_r if i == j else 0),
#                 ]
#             return asn
# 
#         cases = {"default": assign_for_case(0)}
#         for i in range(1, masters_len):
#             cases[i] = assign_for_case(i)
# 
#         self.comb += Case(self.master_select.storage, cases)

class SPIMaster(Module):
    def __init__(self, rst, miso, mosi, sck, ss,
                polarity = 0,
                phase = 0,
                ss_wait = 1,
                enable_miso = 1,
                enable_mosi = 1,
                spi_wid = 24,
                spi_cycle_half_wait = 1,
        ):

        self.bus = Interface(data_width = 32, address_width=32, addressing="byte")
        self.region = SoCRegion(size=0x10, cached=False)

        self.comb += [
                self.bus.err.eq(0),
        ]

        self.specials += Instance("spi_master_ss_wb",
            p_SS_WAIT = ss_wait,
            p_SS_WAIT_TIMER_LEN = minbits(ss_wait),
            p_CYCLE_HALF_WAIT = spi_cycle_half_wait,
            p_TIMER_LEN = minbits(spi_cycle_half_wait),
            p_WID = spi_wid,
            p_WID_LEN = minbits(spi_wid),
            p_ENABLE_MISO = enable_miso,
            p_ENABLE_MOSI = enable_mosi,
            p_POLARITY = polarity,
            p_PHASE = phase,

            i_clk = ClockSignal(),
            i_rst_L = rst,
            i_miso = miso,
            o_mosi = mosi,
            o_sck_wire = sck,
            o_ss_L = ss,

            i_wb_cyc = self.bus.cyc,
            i_wb_stb = self.bus.stb,
            i_wb_we = self.bus.we,
            i_wb_sel = self.bus.sel,
            i_wb_addr = self.bus.adr,
            i_wb_dat_w = self.bus.dat_w,
            o_wb_ack = self.bus.ack,
            o_wb_dat_r = self.bus.dat_r,
        )

# TODO: Generalize CSR stuff
# class ControlLoopParameters(Module, AutoCSR):
#     def __init__(self):
#         self.cl_I = CSRStorage(32, description='Integral parameter')
#         self.cl_P = CSRStorage(32, description='Proportional parameter')
#         self.deltaT = CSRStorage(32, description='Wait parameter')
#         self.setpt = CSRStorage(32, description='Setpoint')
#         self.zset = CSRStatus(32, description='Set Z position')
#         self.zpos = CSRStatus(32, description='Measured Z position')
# 
#         self.bus = Interface(data_width = 32, address_width = 32, addressing="word")
#         self.region = SoCRegion(size=minbits(0x17), cached=False)
#         self.sync += [
#                 If(self.bus.cyc == 1 and self.bus.stb == 1 and self.bus.ack == 0,
#                     Case(self.bus.adr[0:4], {
#                         0x0: self.bus.dat_r.eq(self.cl_I.storage),
#                         0x4: self.bus.dat_r.eq(self.cl_P.storage),
#                         0x8: self.bus.dat_r.eq(self.deltaT.storage),
#                         0xC: self.bus.dat_r.eq(self.setpt.storage),
#                         0x10: If(self.bus.we,
#                                 self.zset.status.eq(self.bus.dat_w)
#                             ).Else(
#                                 self.bus.dat_r.eq(self.zset.status)
#                             ),
#                         0x14: If(self.bus.we,
#                                 self.zpos.status.eq(self.bus.dat_w),
#                             ).Else(
#                                 self.bus.dat_r.eq(self.zpos.status)
#                             ),
#                     }),
#                     self.bus.ack.eq(1),
#                 ).Else(
#                     self.bus.ack.eq(0),
#                 )
#         ]
# 
# class BRAM(Module):
#     """ A BRAM (block ram) is a memory store that is completely separate from
#     the system RAM. They are much smaller.
#     """
#     def __init__(self, addr_mask, origin=None):
#         """
#         :param addr_mask: Mask which defines the amount of bytes accessable
#           by the BRAM.
#         :param origin: Origin of the BRAM module region. This is seen by the
#           subordinate master, not the usual master.
#         """
#         self.bus = Interface(data_width=32, address_width=32, addressing="byte")
# 
#         # Non-IO (i.e. MMIO) regions need to be cached
#         self.region = SoCRegion(origin=origin, size=addr_mask+1, cached=True)
# 
#         self.specials += Instance("bram",
#                 p_ADDR_MASK = addr_mask,
#                 i_clk = ClockSignal(),
#                 i_wb_cyc = self.bus.cyc,
#                 i_wb_stb = self.bus.stb,
#                 i_wb_we = self.bus.we,
#                 i_wb_sel = self.bus.sel,
#                 i_wb_addr = self.bus.adr,
#                 i_wb_dat_w = self.bus.dat_w,
#                 o_wb_ack = self.bus.ack,
#                 o_wb_dat_r = self.bus.dat_r,
#         )
# 
# class PicoRV32(Module, AutoCSR):
#     def __init__(self, bramwid=0x1000):
#         self.submodules.params = params = ControlLoopParameters()
#         self.submodules.bram = self.bram = bram = BRAM(bramwid-1, origin=0x10000)
#         self.submodules.bram_iface = self.bram_iface = bram_iface = PreemptiveInterface(2, bram)
# 
#         # This is the PicoRV32 master
#         self.masterbus = Interface(data_width=32, address_width=32, addressing="byte")
# 
#         self.resetpin = CSRStorage(1, name="picorv32_reset", description="PicoRV32 reset")
#         self.trap = CSRStatus(1, name="picorv32_trap", description="Trap bit")
# 
#         self.ic = ic = SoCBusHandler(
#             standard="wishbone",
#             data_width=32,
#             address_width=32,
#             timeout=1e6,
#             bursting=False,
#             interconnect="shared",
#             interconnect_register=True,
#             reserved_regions={
#                 "picorv32_null_region": SoCRegion(origin=0,size=0x10000, mode="ro", cached=True),
#                 "picorv32_io": SoCIORegion(origin=0x100000, size=0x100, mode="rw", cached=False),
#             },
#         )
# 
#         ic.add_slave("picorv32_bram", bram_iface.buses[1], bram.region)
#         ic.add_slave("picorv32_params", params.bus, params.region)
#         ic.add_master("picorv32_master", self.masterbus)
# 
#         # NOTE: need to compile to these extact instructions
#         self.specials += Instance("picorv32_wb",
#             p_COMPRESSED_ISA = 1,
#             p_ENABLE_MUL = 1,
#             p_PROGADDR_RESET=0x10000,
#             p_PROGADDR_IRQ=0x100010,
#             p_REGS_INIT_ZERO = 1,
#             o_trap = self.trap.status,
# 
#             i_wb_rst_i = ~self.resetpin.storage,
#             i_wb_clk_i = ClockSignal(),
#             o_wbm_adr_o = self.masterbus.adr,
#             o_wbm_dat_o = self.masterbus.dat_r,
#             i_wbm_dat_i = self.masterbus.dat_w,
#             o_wbm_we_o = self.masterbus.we,
#             o_wbm_sel_o = self.masterbus.sel,
#             o_wbm_stb_o = self.masterbus.stb,
#             i_wbm_ack_i = self.masterbus.ack,
#             o_wbm_cyc_o = self.masterbus.cyc,
# 
#             o_pcpi_valid = Signal(),
#             o_pcpi_insn = Signal(32),
#             o_pcpi_rs1 = Signal(32),
#             o_pcpi_rs2 = Signal(32),
#             i_pcpi_wr = 0,
#             i_pcpi_wait = 0,
#             i_pcpi_rd = 0,
#             i_pcpi_ready = 0,
# 
#             i_irq = 0,
#             o_eoi = Signal(32),
# 
#             o_trace_valid = Signal(),
#             o_trace_data = Signal(36),
#         )
# 
#     def do_finalize(self):
#         self.ic.finalize()
#         jsondata = {}
# 
#         for region in self.ic.regions:
#             d = self.ic.regions[region]
#             jsondata[region] = {
#                     "origin": d.origin,
#                     "size": d.size,
#             }
# 
#         with open('picorv32.json', 'w') as f:
#             import json
#             json.dump(jsondata, f)

# Clock and Reset Generator
# I don't know how this works, I only know that it does.
class _CRG(Module):
    def __init__(self, platform, sys_clk_freq, with_dram, rst_pin):
        self.rst = Signal()
        self.clock_domains.cd_sys      = ClockDomain()
        self.clock_domains.cd_eth      = ClockDomain()
        if with_dram:
            self.clock_domains.cd_sys4x  = ClockDomain()
            self.clock_domains.cd_sys4x_dqs = ClockDomain()
            self.clock_domains.cd_idelay    = ClockDomain()

        # Clk/Rst.
        clk100 = platform.request("clk100")
        rst = ~rst_pin if rst_pin is not None else 0

        # PLL.
        self.submodules.pll = pll = S7PLL(speedgrade=-1)
        self.comb += pll.reset.eq(rst | self.rst)
        pll.register_clkin(clk100, 100e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)
        pll.create_clkout(self.cd_eth, 25e6)
        self.comb += platform.request("eth_ref_clk").eq(self.cd_eth.clk)
        platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin) # Ignore sys_clk to pll.clkin path created by SoC's rst.
        if with_dram:
            pll.create_clkout(self.cd_sys4x,     4*sys_clk_freq)
            pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)
            pll.create_clkout(self.cd_idelay,   200e6)

        # IdelayCtrl.
        if with_dram:
            self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_idelay)

class UpsilonSoC(SoCCore):
    def add_ip(self, ip_str, ip_name):
        for seg_num, ip_byte in enumerate(ip_str.split('.'),start=1):
            self.add_constant(f"{ip_name}{seg_num}", int(ip_byte))

    def add_picorv32(self):
        self.submodules.picorv32 = pr = PicoRV32()
        self.bus.add_slave("picorv32_master_bram", pr.bram_iface.buses[0],
                SoCRegion(origin=None,size=pr.bram.region.size, cached=True))

    def add_bram(self):
        self.submodules.bram = br = BRAM(0x1FF)
        self.bus.add_slave("bram", br.bus, br.region)

    def __init__(self,
                 variant="a7-100",
                 local_ip="192.168.2.50",
                 remote_ip="192.168.2.100",
                 tftp_port=6969):
        sys_clk_freq = int(100e6)
        platform = board_spec.Platform(variant=variant, toolchain="f4pga")
        rst = platform.request("cpu_reset")
        self.submodules.crg = _CRG(platform, sys_clk_freq, True, rst)

        """
        These source files need to be sorted so that modules
        that rely on another module come later. For instance,
        `control_loop` depends on `control_loop_math`, so
        control_loop_math.v comes before control_loop.v

        If you want to add a new verilog file to the design, look at the
        modules that it refers to and place it the files with those modules.

        Since Yosys doesn't support modern Verilog, only put preprocessed
        (if applicable) files here.
        """
        #platform.add_source("rtl/picorv32/picorv32.v")
        #platform.add_source("rtl/spi/spi_master.v")
        #platform.add_source("rtl/spi/spi_master_ss.v")
        #platform.add_source("rtl/spi/spi_master_ss_wb.v")
        #platform.add_source("rtl/bram/bram.v")

        # SoCCore does not have sane defaults (no integrated rom)
        SoCCore.__init__(self,
                clk_freq=sys_clk_freq,
                toolchain="symbiflow", 
                platform = platform,
                bus_standard = "wishbone",
                ident = f"Arty-{variant} F4PGA LiteX VexRiscV Zephyr - Upsilon",
                bus_data_width = 32,
                bus_address_width = 32,
                bus_timeout = int(1e6),
                cpu_type = "vexriscv_smp",
                cpu_count = 1,
                cpu_variant="linux",
                integrated_rom_size=0x20000,
                integrated_sram_size = 0x2000,
                csr_data_width=32,
                csr_address_width=14,
                csr_paging=0x800,
                csr_ordering="big",
                timer_uptime = True)
        # This initializes the connection to the physical DRAM interface.
        self.submodules.ddrphy = s7ddrphy.A7DDRPHY(platform.request("ddram"),
            memtype     = "DDR3",
            nphases     = 4,
            sys_clk_freq   = sys_clk_freq)
        # Synchronous dynamic ram. This is what controls all access to RAM.
        # This houses the "crossbar", which negotiates all RAM accesses to different
        # modules, including the verilog interfaces (waveforms etc.)
        self.add_sdram("sdram",
            phy        = self.ddrphy,
            module      = MT41K128M16(sys_clk_freq, "1:4"),
            l2_cache_size = 8192
        )

        # Initialize Ethernet
        self.submodules.ethphy = LiteEthPHYMII(
            clock_pads = platform.request("eth_clocks"),
            pads       = platform.request("eth"))
        self.add_ethernet(phy=self.ethphy, dynamic_ip=True)

        # Initialize network information
        self.add_ip(local_ip, "LOCALIP")
        self.add_ip(remote_ip, "REMOTEIP")
        self.add_constant("TFTP_SERVER_PORT", tftp_port)

        # Add pins
        platform.add_extension(io)
        self.submodules.spi0 = SPIMaster(
                platform.request("module_reset"),
                platform.request("dac_miso_0"),
                platform.request("dac_mosi_0"),
                platform.request("dac_sck_0"),
                platform.request("dac_ss_L_0"),
        )
        self.bus.add_slave("spi0", self.spi0.bus, self.spi0.region)
        
        #self.add_bram()
        #self.add_picorv32()

def main():
    """ Add modifications to SoC variables here """
    soc =UpsilonSoC(variant="a7-35")
    builder = Builder(soc, csr_json="csr.json", compile_software=True)
    builder.build()

if __name__ == "__main__":
    main()
