# Portions of this file incorporate code licensed under the
# BSD 2-Clause License. See COPYING.

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
from litedram.frontend.dma import LiteDRAMDMAReader
from liteeth.phy.mii import LiteEthPHYMII

# Refer to `A7-constraints.xdc` for pin names.
# IO with Subsignals make Record types, which have the name of the
# subsignal as an attribute.
io = [
	("dac_ss_L", 0, Pins("G13 D13 E15 J17 U12 U14 D4 E2"), IOStandard("LVCMOS33")),
	("dac_mosi", 0, Pins("B11 B18 E16 J18 V12 V14 D3 D2"), IOStandard("LVCMOS33")),
	("dac_miso", 0, Pins("A11 A18 D15 K15 V10 T13 F4 H2"), IOStandard("LVCMOS33")),
	("dac_sck", 0, Pins("D12 K16 C15 J15 V11 U13 F3 G2"), IOStandard("LVCMOS33")),
	("adc_conv", 0, Pins("V15 T11 N15 U18 U11 R10 R16 U17"), IOStandard("LVCMOS33")),
	("adc_sck", 0, Pins("U16 R12 M16 R17 V16 R11 N16 T18"), IOStandard("LVCMOS33")),
	("adc_sdo", 0, Pins("P14 T14 V17 P17 M13 R13 N14 R18"), IOStandard("LVCMOS33"))
]

class Base(Module, AutoCSR):
	def __init__(self, clk, sdram, platform):
		for i in range(0,8):
			setattr(self, f"dac_sel_{i}", CSRStorage(3, name=f"dac_sel_{i}"))
			setattr(self, f"dac_finished_{i}", CSRStatus(1, name=f"dac_finished_{i}"))
			setattr(self, f"dac_arm_{i}", CSRStorage(1, name=f"dac_arm_{i}"))
			setattr(self, f"from_dac_{i}", CSRStatus(24, name=f"from_dac_{i}"))
			setattr(self, f"to_dac_{i}", CSRStorage(24, name=f"to_dac_{i}"))
			setattr(self, f"wf_arm_{i}", CSRStorage(1, name=f"wf_arm_{i}"))
			setattr(self, f"wf_halt_on_finish_{i}", CSRStorage(1, name=f"wf_halt_on_finish_{i}")),
			setattr(self, f"wf_finished_{i}", CSRStatus(1, name=f"wf_finished_{i}")),
			setattr(self, f"wf_time_to_wait_{i}", CSRStorage(16, name=f"wf_time_to_wait_{i}"))
			setattr(self, f"wf_refresh_start_{i}", CSRStorage(1, name=f"wf_refresh_start_{i}"))
			setattr(self, f"wf_refresh_finished_{i}", CSRStatus(1, name=f"wf_refresh_finished_{i}"))
			setattr(self, f"wf_start_addr_{i}", CSRStorage(32, name=f"wf_start_addr_{i}"))
			port = sdram.crossbar.get_port()

			setattr(self, f"wf_sdram_{i}", LiteDRAMDMAReader(port))

			setattr(self, f"adc_finished_{i}", CSRStatus(1, name=f"adc_finished_{i}"))
			setattr(self, f"adc_arm_{i}", CSRStorage(1, name=f"adc_arm_{i}"))
			setattr(self, f"from_adc_{i}", CSRStatus(32, name=f"from_adc_{i}"))

		self.adc_sel_0 = CSRStorage(2)
		self.cl_in_loop = CSRStatus(1)
		self.cl_cmd = CSRStorage(64)
		self.cl_word_in = CSRStorage(32)
		self.cl_word_out = CSRStatus(32)
		self.cl_start_cmd = CSRStorage(1)
		self.cl_finish_cmd = CSRStatus(1)

		self.specials += Instance("base",
			i_clk = clk,
			i_dac_miso = platform.request("dac_miso"),
			o_dac_mosi = platform.request("dac_mosi"),
			o_dac_sck = platform.request("dac_sck"),
			o_dac_ss_L = platform.request("dac_ss_L"),
			o_adc_conv = platform.request("adc_conv"),
			i_adc_sdo = platform.request("adc_sdo"),
			o_adc_sck = platform.request("adc_sck"),

			# dac_0
			i_dac_sel_0 = self.dac_sel_0.storage,
			o_dac_finished_0 = self.dac_finished_0.status,
			i_dac_arm_0 = self.dac_arm_0.storage,
			o_from_dac_0 = self.from_dac_0.status,
			i_to_dac_0 = self.to_dac_0.storage,

			i_wf_arm_0 = self.wf_arm_0.storage,
			i_wf_time_to_wait_0 = self.wf_time_to_wait_0.storage,
			i_wf_refresh_start_0 = self.wf_refresh_start_0.storage,
			o_wf_refresh_finished_0 = self.wf_refresh_finished_0.status,
			o_wf_start_addr_0 = self.wf_start_addr_0.storage,

			o_wf_ram_dma_addr_0 = self.wf_sdram_0.sink.address,
			i_wf_ram_word_0 = self.wf_sdram_0.source.data,
			o_wf_ram_read_0 = self.wf_sdram_0.sink.valid,
			i_wf_ram_valid_0 = self.wf_sdram_0.source.valid,

			# dac_1
			i_dac_sel_1 = self.dac_sel_1.storage,
			o_dac_finished_1 = self.dac_finished_1.status,
			i_dac_arm_1 = self.dac_arm_1.storage,
			o_from_dac_1 = self.from_dac_1.status,
			i_to_dac_1 = self.to_dac_1.storage,

			i_wf_arm_1 = self.wf_arm_1.storage,
			i_wf_time_to_wait_1 = self.wf_time_to_wait_1.storage,
			i_wf_refresh_start_1 = self.wf_refresh_start_1.storage,
			o_wf_refresh_finished_1 = self.wf_refresh_finished_1.status,
			o_wf_start_addr_1 = self.wf_start_addr_1.storage,

			o_wf_ram_dma_addr_1 = self.wf_sdram_1.sink.address,
			i_wf_ram_word_1 = self.wf_sdram_1.source.data,
			o_wf_ram_read_1 = self.wf_sdram_1.sink.valid,
			i_wf_ram_valid_1 = self.wf_sdram_1.source.valid,

			# dac_2
			i_dac_sel_2 = self.dac_sel_2.storage,
			o_dac_finished_2 = self.dac_finished_2.status,
			i_dac_arm_2 = self.dac_arm_2.storage,
			o_from_dac_2 = self.from_dac_2.status,
			i_to_dac_2 = self.to_dac_2.storage,

			i_wf_arm_2 = self.wf_arm_2.storage,
			i_wf_time_to_wait_2 = self.wf_time_to_wait_2.storage,
			i_wf_refresh_start_2 = self.wf_refresh_start_2.storage,
			o_wf_refresh_finished_2 = self.wf_refresh_finished_2.status,
			o_wf_start_addr_2 = self.wf_start_addr_2.storage,

			o_wf_ram_dma_addr_2 = self.wf_sdram_2.sink.address,
			i_wf_ram_word_2 = self.wf_sdram_2.source.data,
			o_wf_ram_read_2 = self.wf_sdram_2.sink.valid,
			i_wf_ram_valid_2 = self.wf_sdram_2.source.valid,

			# dac_3
			i_dac_sel_3 = self.dac_sel_3.storage,
			o_dac_finished_3 = self.dac_finished_3.status,
			i_dac_arm_3 = self.dac_arm_3.storage,
			o_from_dac_3 = self.from_dac_3.status,
			i_to_dac_3 = self.to_dac_3.storage,

			i_wf_arm_3 = self.wf_arm_3.storage,
			i_wf_time_to_wait_3 = self.wf_time_to_wait_3.storage,
			i_wf_refresh_start_3 = self.wf_refresh_start_3.storage,
			o_wf_refresh_finished_3 = self.wf_refresh_finished_3.status,
			o_wf_start_addr_3 = self.wf_start_addr_3.storage,

			o_wf_ram_dma_addr_3 = self.wf_sdram_3.sink.address,
			i_wf_ram_word_3 = self.wf_sdram_3.source.data,
			o_wf_ram_read_3 = self.wf_sdram_3.sink.valid,
			i_wf_ram_valid_3 = self.wf_sdram_3.source.valid,

			# dac_4
			i_dac_sel_4 = self.dac_sel_4.storage,
			o_dac_finished_4 = self.dac_finished_4.status,
			i_dac_arm_4 = self.dac_arm_4.storage,
			o_from_dac_4 = self.from_dac_4.status,
			i_to_dac_4 = self.to_dac_4.storage,

			i_wf_arm_4 = self.wf_arm_4.storage,
			i_wf_time_to_wait_4 = self.wf_time_to_wait_4.storage,
			i_wf_refresh_start_4 = self.wf_refresh_start_4.storage,
			o_wf_refresh_finished_4 = self.wf_refresh_finished_4.status,
			o_wf_start_addr_4 = self.wf_start_addr_4.storage,

			o_wf_ram_dma_addr_4 = self.wf_sdram_4.sink.address,
			i_wf_ram_word_4 = self.wf_sdram_4.source.data,
			o_wf_ram_read_4 = self.wf_sdram_4.sink.valid,
			i_wf_ram_valid_4 = self.wf_sdram_4.source.valid,

			# dac_5
			i_dac_sel_5 = self.dac_sel_5.storage,
			o_dac_finished_5 = self.dac_finished_5.status,
			i_dac_arm_5 = self.dac_arm_5.storage,
			o_from_dac_5 = self.from_dac_5.status,
			i_to_dac_5 = self.to_dac_5.storage,

			i_wf_arm_5 = self.wf_arm_5.storage,
			i_wf_time_to_wait_5 = self.wf_time_to_wait_5.storage,
			i_wf_refresh_start_5 = self.wf_refresh_start_5.storage,
			o_wf_refresh_finished_5 = self.wf_refresh_finished_5.status,
			o_wf_start_addr_5 = self.wf_start_addr_5.storage,

			o_wf_ram_dma_addr_5 = self.wf_sdram_5.sink.address,
			i_wf_ram_word_5 = self.wf_sdram_5.source.data,
			o_wf_ram_read_5 = self.wf_sdram_5.sink.valid,
			i_wf_ram_valid_5 = self.wf_sdram_5.source.valid,

			# dac_6
			i_dac_sel_6 = self.dac_sel_6.storage,
			o_dac_finished_6 = self.dac_finished_6.status,
			i_dac_arm_6 = self.dac_arm_6.storage,
			o_from_dac_6 = self.from_dac_6.status,
			i_to_dac_6 = self.to_dac_6.storage,

			i_wf_arm_6 = self.wf_arm_6.storage,
			i_wf_time_to_wait_6 = self.wf_time_to_wait_6.storage,
			i_wf_refresh_start_6 = self.wf_refresh_start_6.storage,
			o_wf_refresh_finished_6 = self.wf_refresh_finished_6.status,
			o_wf_start_addr_6 = self.wf_start_addr_6.storage,

			o_wf_ram_dma_addr_6 = self.wf_sdram_6.sink.address,
			i_wf_ram_word_6 = self.wf_sdram_6.source.data,
			o_wf_ram_read_6 = self.wf_sdram_6.sink.valid,
			i_wf_ram_valid_6 = self.wf_sdram_6.source.valid,

			# dac_7
			i_dac_sel_7 = self.dac_sel_7.storage,
			o_dac_finished_7 = self.dac_finished_7.status,
			i_dac_arm_7 = self.dac_arm_7.storage,
			o_from_dac_7 = self.from_dac_7.status,
			i_to_dac_7 = self.to_dac_7.storage,

			i_wf_arm_7 = self.wf_arm_7.storage,
			i_wf_time_to_wait_7 = self.wf_time_to_wait_7.storage,
			i_wf_refresh_start_7 = self.wf_refresh_start_7.storage,
			o_wf_refresh_finished_7 = self.wf_refresh_finished_7.status,
			o_wf_start_addr_7 = self.wf_start_addr_7.storage,

			o_wf_ram_dma_addr_7 = self.wf_sdram_7.sink.address,
			i_wf_ram_word_7 = self.wf_sdram_7.source.data,
			o_wf_ram_read_7 = self.wf_sdram_7.sink.valid,
			i_wf_ram_valid_7 = self.wf_sdram_7.source.valid,

			i_adc_sel_0 = self.adc_sel_0.storage,

			# adc_0
			o_adc_finished_0 = self.adc_finished_0.status,
			i_adc_arm_0 = self.adc_arm_0.storage,
			o_from_adc_0 = self.from_adc_0.status,

			# adc_1
			o_adc_finished_1 = self.adc_finished_1.status,
			i_adc_arm_1 = self.adc_arm_1.storage,
			o_from_adc_1 = self.from_adc_1.status,

			# adc_2
			o_adc_finished_2 = self.adc_finished_2.status,
			i_adc_arm_2 = self.adc_arm_2.storage,
			o_from_adc_2 = self.from_adc_2.status,

			# adc_3
			o_adc_finished_3 = self.adc_finished_3.status,
			i_adc_arm_3 = self.adc_arm_3.storage,
			o_from_adc_3 = self.from_adc_3.status,

			# adc_4
			o_adc_finished_4 = self.adc_finished_4.status,
			i_adc_arm_4 = self.adc_arm_4.storage,
			o_from_adc_4 = self.from_adc_4.status,

			# adc_5
			o_adc_finished_5 = self.adc_finished_5.status,
			i_adc_arm_5 = self.adc_arm_5.storage,
			o_from_adc_5 = self.from_adc_5.status,

			# adc_6
			o_adc_finished_6 = self.adc_finished_6.status,
			i_adc_arm_6 = self.adc_arm_6.storage,
			o_from_adc_6 = self.from_adc_6.status,

			# adc_7
			o_adc_finished_7 = self.adc_finished_7.status,
			i_adc_arm_7 = self.adc_arm_7.storage,
			o_from_adc_7 = self.from_adc_7.status,

			o_cl_in_loop = self.cl_in_loop.status,
			i_cl_cmd = self.cl_cmd.storage,
			i_cl_word_in = self.cl_word_in.storage,
			o_cl_word_out = self.cl_word_out.status,
			i_cl_start_cmd = self.cl_start_cmd.storage,
			o_cl_finish_cmd = self.cl_finish_cmd.status
		)

# Clock and Reset Generator
class _CRG(Module):
	def __init__(self, platform, sys_clk_freq, with_dram=True, with_rst=True):
		self.rst = Signal()
		self.clock_domains.cd_sys	   = ClockDomain()
		self.clock_domains.cd_eth	   = ClockDomain()
		if with_dram:
			self.clock_domains.cd_sys4x	 = ClockDomain()
			self.clock_domains.cd_sys4x_dqs = ClockDomain()
			self.clock_domains.cd_idelay	= ClockDomain()

		# Clk/Rst.
		clk100 = platform.request("clk100")
		rst	= ~platform.request("cpu_reset") if with_rst else 0

		# PLL.
		self.submodules.pll = pll = S7PLL(speedgrade=-1)
		self.comb += pll.reset.eq(rst | self.rst)
		pll.register_clkin(clk100, 100e6)
		pll.create_clkout(self.cd_sys, sys_clk_freq)
		pll.create_clkout(self.cd_eth, 25e6)
		self.comb += platform.request("eth_ref_clk").eq(self.cd_eth.clk)
		platform.add_false_path_constraints(self.cd_sys.clk, pll.clkin) # Ignore sys_clk to pll.clkin path created by SoC's rst.
		if with_dram:
			pll.create_clkout(self.cd_sys4x,	 4*sys_clk_freq)
			pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)
			pll.create_clkout(self.cd_idelay,	200e6)

		# IdelayCtrl.
		if with_dram:
			self.submodules.idelayctrl = S7IDELAYCTRL(self.cd_idelay)

class CryoSNOM1SoC(SoCCore):
	def __init__(self, variant):
		sys_clk_freq = int(100e6)
		platform = board_spec.Platform(variant=variant, toolchain="f4pga")
		self.submodules.crg = _CRG(platform, sys_clk_freq, True)
		platform.add_source("rtl/spi/spi_switch_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_ss_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_ss_no_write_preprocessed.v")
		platform.add_source("rtl/control_loop/sign_extend.v")
		platform.add_source("rtl/control_loop/intsat.v")
		platform.add_source("rtl/control_loop/boothmul.v")
		platform.add_source("rtl/control_loop/control_loop_math.v")
		platform.add_source("rtl/control_loop/control_loop.v")
		platform.add_source("rtl/waveform/bram_interface_preprocessed.v")
		platform.add_source("rtl/waveform/waveform_preprocessed.v")
		platform.add_source("rtl/base/base.v")

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
				timer_uptime = True)e
		# This initializes the connection to the physical DRAM interface.
		self.submodules.ddrphy = s7ddrphy.A7DDRPHY(platform.request("ddram"),
			memtype		= "DDR3",
			nphases		= 4,
			sys_clk_freq   = sys_clk_freq)
		# Synchronous dynamic ram. This is what controls all access to RAM.
		# This houses the "crossbar", which negotiates all RAM accesses to different
		# modules, including the verilog interfaces (waveforms etc.)
		self.add_sdram("sdram",
			phy		   = self.ddrphy,
			module		= MT41K128M16(sys_clk_freq, "1:4"),
			l2_cache_size = 8192
		)
		self.submodules.ethphy = LiteEthPHYMII(
			clock_pads = platform.request("eth_clocks"),
			pads	   = platform.request("eth"))
		self.add_ethernet(phy=self.ethphy, dynamic_ip=True)

		# Add the DAC and ADC pins as GPIO. They will be used directly
		# by Zephyr.
		platform.add_extension(io)
		self.submodules.base = Base(ClockSignal(), self.sdram, platform)

def main():
	soc = CryoSNOM1SoC("a7-35")
	builder = Builder(soc, csr_json="csr.json", compile_software=False)
	builder.build()

if __name__ == "__main__":
	main()
