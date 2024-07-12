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
    """ This class describes the entire System on a Chip: CPU, ram, peripherals, etc.

        Besides Migen/LiteX's modules, UpsilonSoC also has pre-finalizers
        and mmio-finalizers (called ``mmio_closures``). Pre-finalizers are
        run before code generation to make the main class more declarative.
        Mmio-finalizers are run after generation to define a MicroPython
        library for interacting with the memory-addressed devices attached
        to the SoC.

        Attributes:
    
        * ``mmio_closures``: A list of functions that take one argument, the
          CSR definition.

          Each function returns a string that is then put directly into
          mmio.py (the MicroPython interface).

          This is done to ensure that all finalization has occured before
          generating the address interface.

          They are run after the bitstream has sucessfully been generated.

        * ``soc_subregions``: Dictionary where each key is a valid
          Python identifier, and whose values are dictionaries. Each
          dictionary inside ``soc_subregions`` has keys which are valid
          Python identifiers and values that are instances of region.Register.

        * ``pre_finalize``: A list of functions of 0 arguments that
          are run prior to LiteX finalization. This is used when code
          needs to add modules to the system, which cannot be done at
          LiteX finalization time.

          They are run at the end of the ``__init__`` function.
    """
    def add_ip(self, ip_str, ip_name):
        """ Change the IP hardcoded into the System on a Chip BIOS.

            :param ip_str: IPv4 address in dot-decimal notation.
            :param ip_name: Either "LOCALIP" (the static IP of the SoC) or
               "REMOTEIP" (the IP address of the TFTP server that sends the
               kernel to Upsilon).
        """

        # The IP of the FPGA and the IP of the TFTP server are stored as
        # "constants" which turn into preprocessor defines.

        # They are IPv4 addresses that are split into octets. So the local
        # ip is LOCALIP1, LOCALIP2, etc.
        for seg_num, ip_byte in enumerate(ip_str.split('.'),start=1):
            self.add_constant(f"{ip_name}{seg_num}", int(ip_byte))

    def add_slave_with_registers(self, name, bus, region, registers):
        """ Add a bus reegion connected to a slave device to the SoC's main
            bus with a description of its registers.

            :param name: Name of the region as it will appear in any generated
               code.
            :param bus: An instance of Wishbone.Interface connected to a
               Wishbone slave.
            :param region: An instance of SoCRegion.
            :param registers: A dictionary whose values are valid Python and
               C identifiers (start with character or _, no spaces) and whose
               values are instsances of the Register class in region.py.
        """
        self.bus.add_slave(name, bus, region)
        self.soc_subregions[name] = registers

    def add_preemptive_interface_for_slave(self, name, slave_bus, slave_width, slave_registers, addressing="word"):
        """ Add a PreemptiveInterface in front of a Wishbone Slave interface.

        :param name: Name of the module and the Wishbone bus region.
        :param slave_bus: Instance of Wishbone.Interface.
        :param slave_width: Number of bytes in the region.
        :param slave_registers: A dictionary whose values are valid Python
           identifiers and whose values are instances of region.Register.
        :return: The PI module.
        """
        pi = PreemptiveInterface(slave_bus, addressing=addressing, name=name)
        self.add_module(name, pi)
        self.add_slave_with_registers(name, pi.add_master("main"),
                SoCRegion(origin=None, size=slave_width, cached=False),
                slave_registers)

        self.pre_finalize.append(lambda : pi.pre_finalize(name + "_main_PI.json"))
        self.interface_list.append((name, pi))
        return pi

    def add_blockram(self, name, size):
        """ Add a blockram module to the system. 
            :param name: Name given to the Blockram. This name will be
               used by the MicroPython library to access the ram.
            :param size: Size of the blockram in bytes. Must be a multiple of 32.
        """
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

            self.add_slave_with_registers(
                name + "_params", 
                pico.params.first.bus,
                SoCRegion(origin=None, size=pico.params.width, cached=False),
                pico.params.public_registers)
    
            pico.mmap.add_region(
                "params",
                BasicRegion(origin=pico.param_origin, size=pico.params.width, bus=pico.params.second.bus,
                registers=pico.params.public_registers))
    
        self.pre_finalize.append(pre_finalize)

        # Add a Block RAM for the PicoRV32 to execute from.
        ram, ram_pi = self.add_blockram(name + "_ram", size=size)

        # Add this at the end so the Blockram declaration comes before this one
        def f(csrs):
            param_origin = csrs["memories"][f'{name.lower()}_params']["base"]
            return f'{name}_params = RegisterRegion({param_origin}, {pico.params.mmio(param_origin)})\n' \
                    + f'{name} = PicoRV32({name}_ram, {name}_params, master_selector.{name}_ram_PI_master_selector)'
        self.mmio_closures.append(f)

        # Allow access from the PicoRV32 to the Block RAM.
        pico.mmap.add_region("main",
                BasicRegion(origin=origin, size=size, bus=ram_pi.add_master(name)))

    def picorv32_add_cl(self, name):
        """ Add a register area containing the control loop parameters to the
            PicoRV32. This does not add it to the main CPU.

            :param name: Name of PicoRV32 module.
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
        """ Add a SPI master to the SoC. Unrecognized keyword arguments
            are passed to the module constructor.

            This function will also add ``{name}_PI`` as a preemptive
            interface to control the SPI master from other cores.

            :param name: Name of the SPI master module.
        """
        spi = SPIMaster(**kwargs)
        self.add_module(name, spi)

        pi = self.add_preemptive_interface_for_slave(name + "_PI", spi.bus,
                spi.width, spi.public_registers, "byte")

        def f(csrs):
            wid = kwargs["spi_wid"]
            origin = csrs["memories"][name.lower() + "_pi"]['base']
            return f'{name} = SPI({wid}, master_selector.{name}_PI_master_selector, {origin}, {spi.mmio(origin)})'
        self.mmio_closures.append(f)

        return spi, pi

    def add_AD5791(self, name, **kwargs):
        """ Adds an AD5791 SPI master to the SoC. Argmuents in kwargs will
            override AD5791 defaults. Refer to add_spi_master() for more
            details.

        :return: A tuple of the SPI master module and the PI module.
        """
        args = SPIMaster.AD5791_PARAMS
        args.update(kwargs)
        return self.add_spi_master(name, **args)

    def add_LT_adc(self, name, **kwargs):
        """ Adds a Linear Technologies ADC SPI master to the SoC.
            Argmuents in kwargs will override device defaults. Refer to
            add_spi_master() for more details.

        :return: A tuple of the SPI master module and the PI module.
        """
        args = SPIMaster.LT_ADC_PARAMS
        args.update(kwargs)

        # MOSI is unused by ADC
        args["mosi"] = Signal()

        # SPI Master brings ss_L low when converting and keeps it high
        # when idle. The ADC is the opposite, so invert the signal here.
        conv_pin = args["ss_L"]
        conv_high = Signal()
        args["ss_L"] = conv_high
        self.comb += conv_pin.eq(~conv_high)

        return self.add_spi_master(name, **args)

    def add_waveform(self, name, ram_len, **kwargs):
        """ Add a waveform module to the device.

            Note that by default, the waveform is not attached to any
            SPI device. You need to specify the SPI interface (usually
            through a PreemptiveInterface) using the add_spi() method.

            This function will add a PreemptiveInterface for the
            waveform's RAM.

            :param name: Name of new waveform module.
            :param ram_len: Max number of bytes the waveform will store in
               its own memory. This must be a multiple of 32.
        """

        kwargs['counter_max_wid'] = minbits(ram_len)
        wf = Waveform(**kwargs)

        self.add_module(name, wf)
        pi = self.add_preemptive_interface_for_slave(name + "_PI",
            wf.slavebus, wf.width, wf.public_registers, "byte")

        bram, bram_pi = self.add_blockram(name + "_ram", ram_len)
        wf.add_ram(bram_pi.add_master(name), ram_len)

        def f(csrs):
            param_origin = csrs["memories"][name.lower() + "_pi"]["base"]
            return f'{name} = Waveform({name}_ram, master_selector.{name}_PI_master_selector,'+ \
            f' master_selector.{name}_ram_PI_master_selector, RegisterRegion({param_origin}, {wf.mmio(param_origin)}))'
        self.mmio_closures.append(f)
        return wf, pi

    def __init__(self,
                 variant="a7-100",
                 local_ip="192.168.2.50",
                 remote_ip="192.168.2.100",
                 tftp_port=6969):
        """
        This constructor defines all the modules that the generated
        SoC will have.

        :param variant: Arty A7 variant. Accepts "a7-35" or "a7-100".
        :param local_ip: The IP that the BIOS will use when transmitting.
        :param remote_ip: The IP that the BIOS will use when retreving
          the Linux kernel via TFTP.
        :param tftp_port: Port that the BIOS uses for TFTP.
        """

        # Boilerplate

        sys_clk_freq = int(100e6)
        platform = board_spec.Platform(variant=variant, toolchain="f4pga")
        rst = platform.request("cpu_reset")
        self.submodules.crg = _CRG(platform, sys_clk_freq, True, rst)

        self.soc_subregions = {}
        self.mmio_closures = []
        self.pre_finalize = []

        # Source file reading

        """
        These source files need to be arranged such that modules
        that rely on another module come later.

        If you want to add a new verilog file to the design, look at the
        modules that it refers to and place it the files with those modules.

        Since Yosys doesn't support modern Verilog, only put preprocessed
        (if applicable) files here.
        """
        platform.add_source("rtl/picorv32/picorv32.v")
        platform.add_source("rtl/spi/spi_master_preprocessed.v")
        platform.add_source("rtl/spi/spi_master_ss.v")
        platform.add_source("rtl/waveform/waveform.v")
        platform.add_source("rtl/pd/pd_pipeline.v")

        # Initialize SoC Core

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

        # Before any other Upsilon module is added, the global preemptive
        # interface controller is added. This allows the controlling CPU
        # to control masters on the PreemptiveInterface.
        #
        # When this code adds a preemptive interface, it adds a reference
        # to the interface module to "interface_list", which is then run
        # at the end of pre-finalize after all other preemptive interfaces
        # have finished (post-pre-finalize).

        master_selector = RegisterInterface()
        self.add_module("master_selector", master_selector)
        self.interface_list = []

        def tmp(csrs):
            origin = csrs["memories"]['master_selector']['base']
            vals = master_selector.mmio(origin)
            return f'master_selector = RegisterRegion({origin}, {vals})\n'
        self.mmio_closures.append(tmp)

        #########################
        # Add upsilon modules to this section
        #########################

        for i in range(0,8):
            swic_name = f"pico{i}"
            wf_name = f"wf{i}"
            dac_name = f"dac{i}"
            adc_name = f"adc{i}"

            add_wf = i < 2
            add_swic = i < 2

            # Add control loop DACs and ADCs.
            dac, dac_pi = self.add_AD5791(dac_name,
                rst=module_reset,
                miso=platform.request(f"dac_miso_{i}"),
                mosi=platform.request(f"dac_mosi_{i}"),
                sck=platform.request(f"dac_sck_{i}"),
                ss_L=platform.request(f"dac_ss_L_{i}"),
            )

            adc, adc_pi = self.add_LT_adc(adc_name,
                rst=module_reset,
                miso=platform.request(f"adc_sdo_{i}"),
                sck=platform.request(f"adc_sck_{i}"),
                ss_L=platform.request(f"adc_conv_{i}"),
                spi_wid=18,
            )

            # Add waveform generator.
            if add_wf:
                wf, wf_pi = self.add_waveform(wf_name, 4096)

            # Add SWIC
            if add_swic:
                self.add_picorv32(swic_name)
                self.picorv32_add_cl(swic_name)
                self.picorv32_add_pi(swic_name, dac_name, f"{dac_name}_PI", 0x200000, dac.width, dac.public_registers)
                self.picorv32_add_pi(swic_name, adc_name, f"{adc_name}_PI", 0x300000, adc.width, adc.public_registers)

            if add_wf:
                self.picorv32_add_pi(swic_name, wf_name, f"{wf_name}_PI", 0x400000, wf.width, wf.public_registers)
                wf.add_spi(dac_pi.add_master(wf_name))
            
        #######################
        # End of Upsilon modules section
        #######################

        # Run pre-finalize
        for f in self.pre_finalize:
            f()

        for name, pi in self.interface_list:
            if hasattr(pi, "master_select"):
                master_selector.add_register(name + "_master_selector", False, pi.master_select)

        # Finalize preemptive interface controller.
        master_selector.pre_finalize()
        self.add_slave_with_registers(
            "master_selector",
            master_selector.bus,
            SoCRegion(origin=None, size=master_selector.width, cached=False),
            master_selector.public_registers
        )

    def do_finalize(self):
        """ LiteX finalizer. """

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
soc = UpsilonSoC(**config)
builder = Builder(soc, csr_json="csr.json", compile_software=True, compile_gateware=True)
builder.build()

generate_main_cpu_include(soc.mmio_closures, "csr.json")
