# This file incorporates code from litex-boards.
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

# There is nothing fundamental about the Arty A7(35|100)T to this
# design, but another eval board will require some porting.
from migen import *
import litex_boards.platforms.digilent_arty as board_spec
from litex.soc.cores.gpio import GPIOTristate
from litex.soc.integration.builder import Builder
from litex.build.generic_platform import IOStandard, Pins
from litex.soc.integration.soc_core import SoCCore
from litex.soc.cores.clock import S7PLL, S7IDELAYCTRL

from litedram.phy import s7ddrphy
from litedram.modules import MT41K128M16
from liteeth.phy.mii import LiteEthPHYMII

# Refer to `A7-constraints.xdc` for pin names.
# SS MOSI MISO SCK
io = [
        ("dac0", 0, Pins("G13 B11 A11 D12"), IOStandard("LVCMOS33")),
        ("dac1", 0, Pins("D13 B18 A18 K16"), IOStandard("LVCMOS33")),
        ("dac2", 0, Pins("E15 E16 D15 C15"), IOStandard("LVCMOS33")),
        ("dac3", 0, Pins("J17 J18 K15 J15"), IOStandard("LVCMOS33")),
        ("dac4", 0, Pins("U12 V12 V10 V11"), IOStandard("LVCMOS33")),
        ("dac5", 0, Pins("U14 V14 T13 U13"), IOStandard("LVCMOS33")),
        ("dac6", 0, Pins("D4 D3 F4 F3"), IOStandard("LVCMOS33")),
        ("dac7", 0, Pins("E2 D2 H2 G2"), IOStandard("LVCMOS33")),

        ("adc0", 0, Pins("V15 U16 P14"), IOStandard("LVCMOS33")),
        ("adc1", 0, Pins("T11 R12 T14"), IOStandard("LVCMOS33")),
        ("adc2", 0, Pins("T15 T16 N15"), IOStandard("LVCMOS33")),
        ("adc3", 0, Pins("M16 V17 U18"), IOStandard("LVCMOS33")),
        ("adc4", 0, Pins("U11 V16 M13"), IOStandard("LVCMOS33")),
        ("adc5", 0, Pins("R10 R11 R13"), IOStandard("LVCMOS33")),
        ("adc6", 0, Pins("R15 P15 R16"), IOStandard("LVCMOS33")),
        ("adc7", 0, Pins("N16 N14 U17"), IOStandard("LVCMOS33"))
]

class _CRG(Module):
    def __init__(self, platform, sys_clk_freq, with_dram=True, with_rst=True):
        self.rst = Signal()
        self.clock_domains.cd_sys       = ClockDomain()
        self.clock_domains.cd_eth       = ClockDomain()
        if with_dram:
            self.clock_domains.cd_sys4x     = ClockDomain()
            self.clock_domains.cd_sys4x_dqs = ClockDomain()
            self.clock_domains.cd_idelay    = ClockDomain()


        # # #

        # Clk/Rst.
        clk100 = platform.request("clk100")
        rst    = ~platform.request("cpu_reset") if with_rst else 0

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
            pll.create_clkout(self.cd_idelay,    200e6)

        # IdelayCtrl.
        if with_dram:
            self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_idelay)

class CryoSNOM1SoC(SoCCore):
    def __init__(self, variant):
        sys_clk_freq = int(100e6)
        platform = board_spec.Platform(variant=variant, toolchain="symbiflow")
        self.submodules.crg = _CRG(platform, sys_clk_freq, True)

        # SoCCore does not have sane defaults (no integrated rom)
        SoCCore.__init__(self,
                clk_freq=sys_clk_freq,
                toolchain="symbiflow", 
                platform = platform,
                bus_standard = "wishbone",
                ident = f"Arty-{variant} F4PGA LiteX VexRiscV Zephyr CryoSNOM1 0.1",
                bus_data_width = 32,
                bus_address_width = 32,
                bus_timeout = int(1e6),
                cpu_type = "vexriscv",
                integrated_rom_size=0x20000,
                integrated_sram_size = 0x2000,
                csr_data_width=32,
                csr_address_width=14,
                csr_paging=0x800,
                csr_ordering="big",
                timer_uptime = True)

        self.submodules.ddrphy = s7ddrphy.A7DDRPHY(platform.request("ddram"),
            memtype        = "DDR3",
            nphases        = 4,
            sys_clk_freq   = sys_clk_freq)
        self.add_sdram("sdram",
            phy           = self.ddrphy,
            module        = MT41K128M16(sys_clk_freq, "1:4"),
            l2_cache_size = 8192
        )
        self.submodules.ethphy = LiteEthPHYMII(
            clock_pads = self.platform.request("eth_clocks"),
            pads       = self.platform.request("eth"))
        self.add_ethernet(phy=self.ethphy, dynamic_ip=True)

        # Add the DAC and ADC pins as GPIO. They will be used directly
        # by Zephyr.
        platform.add_extension(io)
        for name in [f"dac{n}" for n in range(0,8)]:
            setattr(self.submodules, name, GPIOTristate(platform.request(name)))
        for name in [f"adc{n}" for n in range(0,8)]:
            setattr(self.submodules, name, GPIOTristate(platform.request(name)))

def main():
    soc = CryoSNOM1SoC("a7-35")
    builder = Builder(soc, csr_json="csr.json")
    builder.build()

if __name__ == "__main__":
    main()
