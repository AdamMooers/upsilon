"""
##########################################################################
# Portions of this file incorporate code licensed under the
# BSD 2-Clause License.
#
# Copyright (c) 2014-2022 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2013-2014 Sebastien Bourdeauducq <sb@m-labs.hk>

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
from litex.soc.interconnect.wishbone import Interface, SRAM, Decoder

from litedram.phy import s7ddrphy
from litedram.modules import MT41K128M16
from litedram.frontend.dma import LiteDRAMDMAReader
from liteeth.phy.mii import LiteEthPHYMII

from util import *
from swic import *
from extio import *

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

TODO: generate declaratively from constraints file.
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

    def add_blockram(self, name, size, connect_now=True):
        mod = SRAM(size)
        self.add_module(name, mod)

        if connect_now:
            self.bus.add_slave(name, mod.bus,
                    SoCRegion(origin=None, size=size, cached=True))
        return mod

    def add_preemptive_interface(self, name, size, slave):
        mod = PreemptiveInterface(size, slave)
        self.add_module(name, mod)
        return mod

    def add_picorv32(self, name, size=0x1000, origin=0x10000, param_origin=0x100000):
        pico = PicoRV32(name, origin, origin+0x10)
        self.add_module(name, pico)
        self.bus.add_slave(name + "_dbg_reg", pico.debug_reg_read.bus,
                SoCRegion(origin=None, size=pico.debug_reg_read.width, cached=False))

        ram = self.add_blockram(name + "_ram", size=size, connect_now=False)
        ram_iface = self.add_preemptive_interface(name + "ram_iface", 2, ram)
        pico.mmap.add_region("main",
                BasicRegion(origin=origin, size=size, bus=ram_iface.buses[1]))

        self.bus.add_slave(name + "_ram", ram_iface.buses[0],
                SoCRegion(origin=None, size=size, cached=True))

        param_iface = pico.add_cl_params(param_origin, name + "_cl.json")
        self.bus.add_slave(name + "_cl", param_iface,
                SoCRegion(origin=None, size=size, cached=False))

    def __init__(self,
                 variant="a7-100",
                 local_ip="192.168.2.50",
                 remote_ip="192.168.2.100",
                 tftp_port=6969):
        """
        :param variant: Arty A7 variant. Accepts "a7-35" or "a7-100".
        :param local_ip: The IP that the BIOS will use when transmitting.
        :param remote_ip: The IP that the BIOS will use when retreving
          the Linux kernel via TFTP.
        :param tftp_port: Port that the BIOS uses for TFTP.
        """

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
        platform.add_source("rtl/picorv32/picorv32.v")
        platform.add_source("rtl/spi/spi_master_preprocessed.v")
        platform.add_source("rtl/spi/spi_master_ss.v")
        platform.add_source("rtl/spi/spi_master_ss_wb.v")

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
        self.bus.add_slave("spi0", self.spi0.bus, SoCRegion(origin=None, size=self.spi0.addr_space_size, cached=False))
        
        self.add_picorv32("pico0")

def main():
    from config import config
    soc =UpsilonSoC(**config)
    builder = Builder(soc, csr_json="csr.json", compile_software=True)
    builder.build()

if __name__ == "__main__":
    main()
