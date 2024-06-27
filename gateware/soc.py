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
from region import BasicRegion
import json

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
#    ("differential_output_low", 0, Pins("J17 J18 K15 J15 U14 V14 T13 U13 B6 E5 A3"), IOStandard("LVCMOS33")),
    ("dac_ss_L_0", 0, Pins("G13"), IOStandard("LVCMOS33")),
    ("dac_mosi_0", 0, Pins("B11"), IOStandard("LVCMOS33")),
    ("dac_miso_0", 0, Pins("A11"), IOStandard("LVCMOS33")),
    ("dac_sck_0", 0, Pins("D12"), IOStandard("LVCMOS33")),

    ("dac_ss_L_1", 0, Pins("D13"), IOStandard("LVCMOS33")),
    ("dac_mosi_1", 0, Pins("B18"), IOStandard("LVCMOS33")),
    ("dac_miso_1", 0, Pins("A18"), IOStandard("LVCMOS33")),
    ("dac_sck_1", 0, Pins("K16"), IOStandard("LVCMOS33")),

    ("dac_ss_L_2", 0, Pins("E15"), IOStandard("LVCMOS33")),
    ("dac_mosi_2", 0, Pins("E16"), IOStandard("LVCMOS33")),
    ("dac_miso_2", 0, Pins("D15"), IOStandard("LVCMOS33")),
    ("dac_sck_2", 0, Pins("C15"), IOStandard("LVCMOS33")),

    ("dac_ss_L_3", 0, Pins("F5"), IOStandard("LVCMOS33")),
    ("dac_mosi_3", 0, Pins("D8"), IOStandard("LVCMOS33")),
    ("dac_miso_3", 0, Pins("C7"), IOStandard("LVCMOS33")),
    ("dac_sck_3", 0, Pins("E7"), IOStandard("LVCMOS33")),

    ("dac_ss_L_4", 0, Pins("U12"), IOStandard("LVCMOS33")),
    ("dac_mosi_4", 0, Pins("V12"), IOStandard("LVCMOS33")),
    ("dac_miso_4", 0, Pins("V10"), IOStandard("LVCMOS33")),
    ("dac_sck_4", 0, Pins("V11"), IOStandard("LVCMOS33")),

    ("dac_ss_L_5", 0, Pins("D7"), IOStandard("LVCMOS33")),
    ("dac_mosi_5", 0, Pins("D5"), IOStandard("LVCMOS33")),
    ("dac_miso_5", 0, Pins("B7"), IOStandard("LVCMOS33")),
    ("dac_sck_5", 0, Pins("E6"), IOStandard("LVCMOS33")),

    ("dac_ss_L_6", 0, Pins("D4"), IOStandard("LVCMOS33")),
    ("dac_mosi_6", 0, Pins("D3"), IOStandard("LVCMOS33")),
    ("dac_miso_6", 0, Pins("F4"), IOStandard("LVCMOS33")),
    ("dac_sck_6", 0, Pins("F3"), IOStandard("LVCMOS33")),

    ("dac_ss_L_7", 0, Pins("E2"), IOStandard("LVCMOS33")),
    ("dac_mosi_7", 0, Pins("D2"), IOStandard("LVCMOS33")),
    ("dac_miso_7", 0, Pins("H2"), IOStandard("LVCMOS33")),
    ("dac_sck_7", 0, Pins("G2"), IOStandard("LVCMOS33")),

    ("adc_conv_0", 0, Pins("V15"), IOStandard("LVCMOS33")),
    ("adc_sck_0", 0, Pins("U16"), IOStandard("LVCMOS33")),
    ("adc_sdo_0", 0, Pins("P14"), IOStandard("LVCMOS33")),

    ("adc_conv_1", 0, Pins("T11"), IOStandard("LVCMOS33")),
    ("adc_sck_1", 0, Pins("R12"), IOStandard("LVCMOS33")),
    ("adc_sdo_1", 0, Pins("T14"), IOStandard("LVCMOS33")),

    ("adc_conv_2", 0, Pins("N15"), IOStandard("LVCMOS33")),
    ("adc_sck_2", 0, Pins("M16"), IOStandard("LVCMOS33")),
    ("adc_sdo_2", 0, Pins("V17"), IOStandard("LVCMOS33")),

    ("adc_conv_3", 0, Pins("U18"), IOStandard("LVCMOS33")),
    ("adc_sck_3", 0, Pins("R17"), IOStandard("LVCMOS33")),
    ("adc_sdo_3", 0, Pins("P17"), IOStandard("LVCMOS33")),

    ("adc_conv_4", 0, Pins("U11"), IOStandard("LVCMOS33")),
    ("adc_sck_4", 0, Pins("V16"), IOStandard("LVCMOS33")),
    ("adc_sdo_4", 0, Pins("M13"), IOStandard("LVCMOS33")),

    ("adc_conv_5", 0, Pins("R10"), IOStandard("LVCMOS33")),
    ("adc_sck_5", 0, Pins("R11"), IOStandard("LVCMOS33")),
    ("adc_sdo_5", 0, Pins("R13"), IOStandard("LVCMOS33")),

    ("adc_conv_6", 0, Pins("R16"), IOStandard("LVCMOS33")),
    ("adc_sck_6", 0, Pins("N16"), IOStandard("LVCMOS33")),
    ("adc_sdo_6", 0, Pins("N14"), IOStandard("LVCMOS33")),

    ("adc_conv_7", 0, Pins("U17"), IOStandard("LVCMOS33")),
    ("adc_sck_7", 0, Pins("T18"), IOStandard("LVCMOS33")),
    ("adc_sdo_7", 0, Pins("R18"), IOStandard("LVCMOS33")),

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
        # The IP of the FPGA and the IP of the TFTP server are stored as
        # "constants" which turn into preprocessor defines.

        # They are IPv4 addresses that are split into octets. So the local
        # ip is LOCALIP1, LOCALIP2, etc.
        for seg_num, ip_byte in enumerate(ip_str.split('.'),start=1):
            self.add_constant(f"{ip_name}{seg_num}", int(ip_byte))

    def add_slave_with_registers(self, name, bus, region, registers):
        """ Add a bus slave, and also add its registers to the subregions
        dictionary. """
        self.bus.add_slave(name, bus, region)
        self.soc_subregions[name] = registers

    def add_preemptive_interface_for_slave(self, name, slave_bus, slave_width, slave_registers, addressing="word"):
        """ Add a PreemptiveInterface in front of a Wishbone Slave interface.

        :param name: Name of the module and the Wishbone bus region.
        :param slave_bus: Instance of Wishbone.Interface.
        :param slave_width: Width of the region.
        :param slave_registers: Register inside the bus region.
        :return: The PI module.
        """
        pi = PreemptiveInterface(slave_bus, addressing=addressing, name=name)
        self.add_module(name, pi)
        self.add_slave_with_registers(name, pi.add_master("main"),
                SoCRegion(origin=None, size=slave_width, cached=False),
                slave_registers)

        def f(csrs):
            # CSRs are not case-folded, but Wishbone memory regions are!!
            return f'{name} = Register({csrs["csr_registers"][name + "_master_select"]["addr"]})'

        self.mmio_closures.append(f)
        self.pre_finalize.append(lambda : pi.pre_finalize(name + "_main_PI.json"))
        return pi

    def add_blockram(self, name, size):
        """ Add a blockram module to the system.  """
        mod = SRAM(size)
        self.add_module(name, mod)

        pi = self.add_preemptive_interface_for_slave(name + "_PI", mod.bus,
                size, None, "word")

        def f(csrs):
            return f'{name} = FlatArea({csrs["memories"][name.lower() + "_pi"]["base"]}, {size})'
        self.mmio_closures.append(f)

        return mod, pi

    def add_picorv32(self, name, size=0x1000, origin=0x10000, param_origin=0x100000):
        """ Add a PicoRV32 core.

        :param name: Name of the PicoRV32 module in the Main CPU.
        :param size: Size of the PicoRV32 RAM region.
        :param origin: Start position of the PicoRV32.
        :param param_origin: Origin of the PicoRV32 param region in the PicoRV32
           memory.
        """
        # Add PicoRV32 core
        pico = PicoRV32(name, origin, origin+0x10, param_origin)
        self.add_module(name, pico)

        # Attach registers to main CPU at pre-finalize time.
        def pre_finalize():
            pico.params.pre_finalize()
            self.add_slave_with_registers(name + "_params", pico.params.firstbus,
                SoCRegion(origin=None, size=pico.params.width, cached=False),
                pico.params.public_registers)
            pico.mmap.add_region("params",
                BasicRegion(origin=pico.param_origin, size=pico.params.width, bus=pico.params.secondbus,
                    registers=pico.params.public_registers))
        self.pre_finalize.append(pre_finalize)

        # Add a Block RAM for the PicoRV32 toexecute from.
        ram, ram_pi = self.add_blockram(name + "_ram", size=size)

        # Add this at the end so the Blockram declaration comes before this one
        def f(csrs):
            param_origin = csrs["memories"][f'{name.lower()}_params']["base"]
            return f'{name}_params = RegisterRegion({param_origin}, {pico.params.mmio(param_origin)})\n' \
                    + f'{name} = PicoRV32({name}_ram, {name}_params, {name}_ram_PI)'
        self.mmio_closures.append(f)

        # Allow access from the PicoRV32 to the Block RAM.
        pico.mmap.add_region("main",
                BasicRegion(origin=origin, size=size, bus=ram_pi.add_master(name)))

    def picorv32_add_cl(self, name):
        """ Add a register area containing the control loop parameters to the
            PicoRV32.
        """
        pico = self.get_module(name)
        params = pico.add_cl_params()

    def picorv32_add_pi(self, name, region_name, pi_name, origin, width, registers):
        """ Add a PreemptiveInterface master to a PicoRV32 MemoryMap region.

        :param name: Name of the PicoRV32 module.
        :param region_name: Name of the region in the PicoRV32 MMAP.
        :param pi_name: Name of the PreemptiveInterface module in the main CPU.
        :param origin: Origin of the memory region in the PicoRV32.
        :param width: Width of the region in the PicoRV32.
        :param registers: Registers of the region.
        """
        pico = self.get_module(name)
        pi = self.get_module(pi_name)

        pico.mmap.add_region(region_name,
                BasicRegion(origin=origin, size=width,
                    bus=pi.add_master(name), registers=registers))

    def add_spi_master(self, name, **kwargs):
        spi = SPIMaster(**kwargs)
        self.add_module(name, spi)

        pi = self.add_preemptive_interface_for_slave(name + "_PI", spi.bus,
                spi.width, spi.public_registers, "byte")

        def f(csrs):
            wid = kwargs["spi_wid"]
            origin = csrs["memories"][name.lower() + "_pi"]['base']
            return f'{name} = SPI({wid}, {name}_PI, {origin}, {spi.mmio(origin)})'
        self.mmio_closures.append(f)

        return spi, pi

    def add_AD5791(self, name, **kwargs):
        """ Adds an AD5791 SPI master to the SoC.

        :return: A tuple of the SPI master module and the PI module.
        """
        args = SPIMaster.AD5791_PARAMS
        args.update(kwargs)
        return self.add_spi_master(name, **args)

    def add_LT_adc(self, name, **kwargs):
        """ Adds a Linear Technologies ADC SPI master to the SoC.

        :return: A tuple of the SPI master module and the PI module.
        """
        args = SPIMaster.LT_ADC_PARAMS
        args.update(kwargs)
        args["mosi"] = Signal()

        # SPI Master brings ss_L low when converting and keeps it high
        # when idle. The ADC is the opposite, so invert the signal here.
        conv_pin = args["ss_L"]
        conv_high = Signal()
        args["ss_L"] = conv_high
        self.comb += conv_pin.eq(~conv_high)

        return self.add_spi_master(name, **args)

    def add_waveform(self, name, ram_len, **kwargs):
        # TODO: Either set the SPI interface at instantiation time,
        # or allow waveform to read more than one SPI bus (either by
        # master switching or addressing by Waveform).
        kwargs['counter_max_wid'] = minbits(ram_len)
        wf = Waveform(**kwargs)

        self.add_module(name, wf)
        pi = self.add_preemptive_interface_for_slave(name + "_PI",
            wf.slavebus, wf.width, wf.public_registers, "byte")

        bram, bram_pi = self.add_blockram(name + "_ram", ram_len)
        wf.add_ram(bram_pi.add_master(name), ram_len)

        def f(csrs):
            param_origin = csrs["memories"][name.lower() + "_pi"]["base"]
            return f'{name} = Waveform({name}_ram, {name}_PI, {name}_ram_PI, RegisterRegion({param_origin}, {wf.mmio(param_origin)}))'
        self.mmio_closures.append(f)
        return wf, pi

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

        # The SoC won't know the origins until LiteX sorts out all the
        # memory regions, so they go into a dictionary directly instead
        # of through MemoryMap.
        self.soc_subregions = {}

        # The SoC generates a Python module containing information about
        # how to access registers from Micropython. This is a list of
        # closures that print the code that will be placed in the module.
        self.mmio_closures = []

        # This is a list of closures that are run "pre-finalize", which
        # is before the do_finalize() function is called.
        self.pre_finalize = []

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
        platform.add_source("rtl/waveform/waveform.v")

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
        module_reset = platform.request("module_reset")

        for i in range(0,1):
            swic_name = f"pico{i}"
            wf_name = f"wf{i}"
            dac_name = f"dac{i}"
            adc_name = f"adc{i}"

            # Add control loop DACs and ADCs.
            self.add_picorv32(swic_name)
            self.picorv32_add_cl(swic_name)

            # Add waveform generator.
            wf, wf_pi = self.add_waveform(wf_name, 4096)
            self.picorv32_add_pi(swic_name, wf_name, f"{wf_name}_PI", 0x400000, wf.width, wf.public_registers)

            dac, dac_pi = self.add_AD5791(dac_name,
                rst=module_reset,
                miso=platform.request(f"dac_miso_{i}"),
                mosi=platform.request(f"dac_mosi_{i}"),
                sck=platform.request(f"dac_sck_{i}"),
                ss_L=platform.request(f"dac_ss_L_{i}"),
            )
            self.picorv32_add_pi(swic_name, dac_name, f"{dac_name}_PI", 0x200000, dac.width, dac.public_registers)
            wf.add_spi(dac_pi.add_master(wf_name))

            adc, adc_pi = self.add_LT_adc(adc_name,
                rst=module_reset,
                miso=platform.request(f"adc_sdo_{i}"),
                sck=platform.request(f"adc_sck_{i}"),
                ss_L=platform.request(f"adc_conv_{i}"),
                spi_wid=18,
            )
            self.picorv32_add_pi(swic_name, adc_name, f"{adc_name}_PI", 0x300000, adc.width, adc.public_registers)

        # Run pre-finalize
        for f in self.pre_finalize:
            f()

    def do_finalize(self):
        with open('soc_subregions.json', 'wt') as f:
            regions = self.soc_subregions.copy()
            for k in regions:
                if regions[k] is not None:
                    regions[k] = {name : reg._to_dict() for name, reg in regions[k].items()}
            json.dump(regions, f)

def generate_main_cpu_include(closures, csr_file):
    """ Generate Micropython include from a JSON file. """
    with open('mmio.py', 'wt') as out:

        print("from registers import *", file=out)
        print("from waveform import *", file=out)
        print("from picorv32 import *", file=out)
        print("from spi import *", file=out)
        with open(csr_file, 'rt') as f:
            csrs = json.load(f)

        for f in closures:
            print(f(csrs), file=out)

from config import config
soc =UpsilonSoC(**config)
builder = Builder(soc, csr_json="csr.json", compile_software=True, compile_gateware=True)
builder.build()

generate_main_cpu_include(soc.mmio_closures, "csr.json")
