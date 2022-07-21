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
from litex.build.generic_platform import IOStandard, Pins, Subsignal
from litex.soc.integration.soc_core import SoCCore
from litex.soc.cores.clock import S7PLL, S7IDELAYCTRL
from litex.soc.interconnect.csr import AutoCSR, Module, CSRStorage, CSRStatus

from litedram.phy import s7ddrphy
from litedram.modules import MT41K128M16
from liteeth.phy.mii import LiteEthPHYMII

# Refer to `A7-constraints.xdc` for pin names.
# IO with Subsignals make Record types, which have the name of the
# subsignal as an attribute.
io = [
        ("dac", 0,
            Subsignal("ss", Pins("G13")),
            Subsignal("mosi", Pins("B11")),
            Subsignal("miso", Pins("A11")),
            Subsignal("sck", Pins("D12")),
            IOStandard("LVCMOS33")),
        ("dac", 1,
            Subsignal("ss", Pins("D13")),
            Subsignal("mosi", Pins("B18")),
            Subsignal("miso", Pins("A18")),
            Subsignal("sck", Pins("K16")),
            IOStandard("LVCMOS33")),
        ("dac", 2,
            Subsignal("ss", Pins("E15")),
            Subsignal("mosi", Pins("E16")),
            Subsignal("miso", Pins("D15")),
            Subsignal("sck", Pins("C15")),
            IOStandard("LVCMOS33")),
        ("dac", 3,
            Subsignal("ss", Pins("J17")),
            Subsignal("mosi", Pins("J18")),
            Subsignal("miso", Pins("K15")),
            Subsignal("sck", Pins("J15")),
            IOStandard("LVCMOS33")),
        ("dac", 4,
            Subsignal("ss", Pins("U12")),
            Subsignal("mosi", Pins("V12")),
            Subsignal("miso", Pins("V10")),
            Subsignal("sck", Pins("V11")),
            IOStandard("LVCMOS33")),
        ("dac", 5,
            Subsignal("ss", Pins("U14")),
            Subsignal("mosi", Pins("V14")),
            Subsignal("miso", Pins("T13")),
            Subsignal("sck", Pins("U13")),
            IOStandard("LVCMOS33")),
        ("dac", 6,
            Subsignal("ss", Pins("D4")),
            Subsignal("mosi", Pins("D3")),
            Subsignal("miso", Pins("F4")),
            Subsignal("sck", Pins("F3")),
            IOStandard("LVCMOS33")),
        ("dac", 7,
            Subsignal("ss", Pins("E2")),
            Subsignal("mosi", Pins("D2")),
            Subsignal("miso", Pins("H2")),
            Subsignal("sck", Pins("G2")),
            IOStandard("LVCMOS33")),

        ("adc", 0,
                Subsignal("conv", Pins("V15")),
                Subsignal("sck", Pins("U16")),
                Subsignal("sdo", Pins("P14")),
                IOStandard("LVCMOS33")),
        ("adc", 1,
                Subsignal("conv", Pins("T11")),
                Subsignal("sck", Pins("R12")),
                Subsignal("sdo", Pins("T14")),
                IOStandard("LVCMOS33")),
        ("adc", 2,
                Subsignal("conv", Pins("N15")),
                Subsignal("sck", Pins("M16")),
                Subsignal("sdo", Pins("V17")),
                IOStandard("LVCMOS33")),
        ("adc", 3,
                Subsignal("conv", Pins("U18")),
                Subsignal("sck", Pins("R17")),
                Subsignal("sdo", Pins("P17")),
                IOStandard("LVCMOS33")),
        ("adc", 4,
                Subsignal("conv", Pins("U11")),
                Subsignal("sck", Pins("V16")),
                Subsignal("sdo", Pins("M13")),
                IOStandard("LVCMOS33")),
        ("adc", 5,
                Subsignal("conv", Pins("R10")),
                Subsignal("sck", Pins("R11")),
                Subsignal("sdo", Pins("R13")),
                IOStandard("LVCMOS33")),
        ("adc", 6,
                Subsignal("conv", Pins("R16")),
                Subsignal("sck", Pins("N16")),
                Subsignal("sdo", Pins("N14")),
                IOStandard("LVCMOS33")),
        ("adc", 7,
                Subsignal("conv", Pins("U17")),
                Subsignal("sck", Pins("T18")),
                Subsignal("sdo", Pins("R18")),
                IOStandard("LVCMOS33"))
]

class SPIMaster(Module, AutoCSR):
    def __init__(self, wid, clk, pins):
        self.pins = pins

        self.from_slave = CSRStatus(wid, description="Data from slave (Status)")
        self.to_slave = CSRStorage(wid, description="Data to slave (Control)")
        self.finished = CSRStatus(1, description="Finished transmission (Status)")
        self.arm = CSRStorage(1, description="Initiate transmission (Status)")
        self.ss = CSRStorage(1, description="Slave Select (active high)")

        self.comb += self.pins.ss.eq(~self.ss.storage)

        import math

        self.specials += Instance("spi_master",
                p_WID=wid,
                p_WID_LEN=math.ceil(math.log2(wid)),
                p_CYCLE_HALF_WAIT = 3, # 3 + 2 = 5, total sck = 10 cycles
                p_TIMER_LEN = 3,
                p_POLARITY = 0,
                p_PHASE = 1,
                i_clk = clk,
                o_from_slave = self.from_slave.status,
                i_miso = self.pins.miso,
                i_to_slave = self.to_slave.storage,
                o_mosi = self.pins.mosi,
                o_sck_wire = self.pins.sck,
                o_finished = self.finished.status,
                i_arm = self.arm.storage
        )

class SPIMasterReadOnly(Module, AutoCSR):
    def __init__(self, wid, clk, pins):
        self.pins = pins

        self.from_slave = CSRStatus(wid, description="Data from slave (Status)description=")
        self.finished = CSRStatus(1, description="Finished transmission (Status)description=")
        self.arm = CSRStorage(1, description="Initiate transmission (Status)description=")
        self.conv = CSRStorage(1, description="Conversion (active high)description=")

        self.comb += self.pins.conv.eq(self.conv.storage)

        import math

        self.specials += Instance("spi_master_no_write",
                p_WID=wid,
                p_WID_LEN=math.ceil(math.log2(wid)),
                p_CYCLE_HALF_WAIT = 1, # 1 + 2 = 3, total sck = 6 cycles
                p_TIMER_LEN = 3,
                p_POLARITY = 1,
                p_PHASE = 0,
                i_clk = clk,
                o_from_slave = self.from_slave.status,
                i_miso = self.pins.sdo,
                o_sck_wire = self.pins.sck,
                o_finished = self.finished.status,
                i_arm = self.arm.storage
        )

# Clock and Reset Generator
class _CRG(Module):
    def __init__(self, platform, sys_clk_freq, with_dram=True, with_rst=True):
        self.rst = Signal()
        self.clock_domains.cd_sys       = ClockDomain()
        self.clock_domains.cd_eth       = ClockDomain()
        if with_dram:
            self.clock_domains.cd_sys4x     = ClockDomain()
            self.clock_domains.cd_sys4x_dqs = ClockDomain()
            self.clock_domains.cd_idelay    = ClockDomain()

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
        platform.add_source("rtl/spi/spi_master.v")
        platform.add_source("rtl/spi/spi_master_no_write.v")

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
            clock_pads = platform.request("eth_clocks"),
            pads       = platform.request("eth"))
        self.add_ethernet(phy=self.ethphy, dynamic_ip=True)

        # Add the DAC and ADC pins as GPIO. They will be used directly
        # by Zephyr.
        platform.add_extension(io)
        for i in range(0,8):
            setattr(self.submodules, f"dac{i}", SPIMaster(24, ClockSignal(), platform.request("dac", i)))
            setattr(self.submodules, f"adc{i}", SPIMasterReadOnly(24, ClockSignal(), platform.request("adc", i)))

def main():
    soc = CryoSNOM1SoC("a7-35")
    builder = Builder(soc, csr_json="csr.json")
    builder.build()

if __name__ == "__main__":
    main()
