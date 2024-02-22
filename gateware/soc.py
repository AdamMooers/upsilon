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

class PreemptiveInterface(Module, AutoCSR):
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
         Construct a combinatorial case statement. In verilog, the if
         statment would look like
 
             always @ (*) case (master_select)
                 1: begin
                     // Bus assignments...
                 end
                 2: begin
                     // Bus assignments...
                 end
                 // more cases:
                 default:
                     // assign everything to master 0
                 end
 
         The If statement in Migen (Python HDL) is an object with a method
         called "ElseIf" and "Else", that return objects with the specified
         case attached. Instead of directly writing an If statement into
         the combinatorial block, the If statement is constructed in a
         for loop.
 
         Avoiding latches:
         Left hand sign (assignment) is always an input.
         """
 
         def assign_for_case(current_case):
             asn = [ ]
 
             for j in range(masters_len):
                 if current_case == j:
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
                     asn += [
                         self.buses[j].dat_r.eq(0),
                         self.buses[j].ack.eq(self.buses[j].cyc & self.buses[j].stb),
                     ]
             return asn
 
         cases = {"default": assign_for_case(0)}
         for i in range(1, masters_len):
             cases[i] = assign_for_case(i)
 
         self.comb += Case(self.master_select.storage, cases)

class SPIMaster(Module):
    """ Wrapper for the SPI master verilog code. """
    def __init__(self, rst, miso, mosi, sck, ss,
                polarity = 0,
                phase = 0,
                ss_wait = 1,
                enable_miso = 1,
                enable_mosi = 1,
                spi_wid = 24,
                spi_cycle_half_wait = 1,
        ):
        """
        :param rst: Reset signal.
        :param miso: MISO signal.
        :param mosi: MOSI signal.
        :param sck: SCK signal.
        :param ss: SS signal.
        :param phase: Phase of SPI master. This phase is not the standard
          SPI phase because it is defined in terms of the rising edge, not
          the leading edge. See <https://software.mcgoron.com/peter/spi>
        :param polarity: See <https://software.mcgoron.com/peter/spi>.
        :param enable_miso: If ``False``, the module does not read data
          from MISO into a register.
        :param enable_mosi: If ``False``, the module does not write data
          to MOSI from a register.
        :param spi_wid: Verilog parameter: see file.
        :param spi_cycle_half_wait: Verilog parameter: see file.
        """

        self.bus = Interface(data_width = 32, address_width=32, addressing="word")
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

 #TODO: Generalize CSR stuff
class ControlLoopParameters(Module, AutoCSR):
    """ Interface for the Linux CPU to write parameters to the CPU
        and for the CPU to write data back to the CPU without complex
        locking mechanisms.
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

class BasicRegion:
    """ Simple class for storing a RAM region. """
    def __init__(self, origin, size, bus=None):
        self.origin = origin
        self.size = size
        self.bus = bus

    def decoder(self):
        """
        Wishbone decoder generator. The decoder looks at the high
        bits of the address to check what bits are passed to the
        slave device.

        Examples:

        Location 0x10000 has 0xFFFF of address space.
        origin = 0x10000, rightbits = 16.

        Location 0x10000 has 0xFFF of address space.
        origin = 0x10000, rightbits = 12.

        Location 0x100000 has 0x1F of address space.
        origin = 0x100000, rightbits = 5.
        """
        rightbits = minbits(self.size-1)
        print(self.origin, self.origin >> rightbits)
        return lambda addr: addr[rightbits:32] == (self.origin >> rightbits)

    def to_dict(self):
        return {"origin" : self.origin, "size": self.size}

    def __str__(self):
        return str(self.to_dict())

class MemoryMap:
    """ Stores the memory map of an embedded core. """
    def __init__(self):
        self.regions = {}

    def add_region(self, name, region):
        assert name not in self.regions
        self.regions[name] = region

    def dump_json(self, jsonfile):
        with open(jsonfile, 'wt') as f:
            import json
            json.dump({k : self.regions[k].to_dict() for k in self.regions}, f)

    def bus_submodule(self, masterbus):
        """ Return a module that decodes the masterbus into the
            slave devices according to their origin and start positions. """
        slaves = [(self.regions[n].decoder(), self.regions[n].bus)
                for n in self.regions]
        return Decoder(masterbus, slaves, register=False)
 
class PicoRV32(Module, AutoCSR):
    def add_ram(self, name, width, origin):
        mod = SRAM(width)
        self.submodules += mod

        self.mmap.add_region(name, BasicRegion(width, origin, mod.bus))

    def add_params(self, origin):
        self.submodules.params = params = ControlLoopParameters()
        self.mmap.add_region('params', BasicRegion(origin, params.width, params.bus))

    def __init__(self, name, start_addr=0x10000, irq_addr=0x10010):
        self.mmap = MemoryMap()
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
            o_wbm_dat_o = self.masterbus.dat_r,
            i_wbm_dat_i = self.masterbus.dat_w,
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
        self.mmap.dump_json(self.name + ".json")
        self.submodules.decoder = self.mmap.bus_submodule(self.masterbus)

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
        assert not hasattr(self.submodules, name)
        mod = SRAM(size)
        setattr(self.submodules, name, mod)

        if connect_now:
            self.bus.add_slave(name, mod.bus,
                    SoCRegion(origin=None, size=size, cached=True))
        return mod

    def add_preemptive_interface(self, name, size, slave):
        assert not hasattr(self.submodules, name)
        mod = PreemptiveInterface(size, slave)
        setattr(self.submodules, name, mod)
        return mod

    def add_picorv32(self, name, size=0x1000, origin=0x10000, param_origin=0x100000):
        assert not hasattr(self.submodules, name)
        pico = PicoRV32(name, origin, origin+0x10)
        setattr(self.submodules, name, pico)

        ram = self.add_blockram(name + "_ram", size=size, connect_now=False)
        ram_iface = self.add_preemptive_interface(name + "ram_iface", 2, ram)
        pico.mmap.add_region("main",
                BasicRegion(origin=origin, size=size, bus=ram_iface.buses[1]))

        self.bus.add_slave(name + "_ram", ram_iface.buses[0],
                SoCRegion(origin=None, size=size, cached=True))

        pico.add_params(param_origin)

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
        self.bus.add_slave("spi0", self.spi0.bus, self.spi0.region)
        
        self.add_picorv32("pico0")

def main():
    """ Add modifications to SoC variables here """
    soc =UpsilonSoC(variant="a7-100")
    builder = Builder(soc, csr_json="csr.json", compile_software=True)
    builder.build()

if __name__ == "__main__":
    main()
