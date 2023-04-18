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
io = [
	("dac_ss_L", 0, Pins("G13 D13 E15 J17 U12 U14 D4 E2"), IOStandard("LVCMOS33")),
	("dac_mosi", 0, Pins("B11 B18 E16 J18 V12 V14 D3 D2"), IOStandard("LVCMOS33")),
	("dac_miso", 0, Pins("A11 A18 D15 K15 V10 T13 F4 H2"), IOStandard("LVCMOS33")),
	("dac_sck", 0, Pins("D12 K16 C15 J15 V11 U13 F3 G2"), IOStandard("LVCMOS33")),
	("adc_conv", 0, Pins("V15 T11 N15 U18 U11 R10 R16 U17"), IOStandard("LVCMOS33")),
	("adc_sck", 0, Pins("U16 R12 M16 R17 V16 R11 N16 T18"), IOStandard("LVCMOS33")),
	("adc_sdo", 0, Pins("P14 T14 V17 P17 M13 R13 N14 R18"), IOStandard("LVCMOS33"))
]

# TODO: Generate widths based off of include files (m4 generated)

class Base(Module, AutoCSR):
	""" The subclass AutoCSR will automatically make CSRs related
	to this class when those CSRs are attributes (i.e. accessed by
	`self.csr_name`) of instances of this class.

	Since there are a lot of input and output wires, the CSRs are
	assigned using `setattr()`.

	CSRs are for input wires (`CSRStorage`) or output wires
	(`CSRStatus`).	The first argument to the CSR constructor is
	the amount of bits the CSR takes. The `name` keyword argument
	is required since the constructor needs the name of the attribute.
	The `description` keyword is used for documentation.

	In LiteX, modules in separate Verilog files are instantiated as
	    self.specials += Instance(
	        "module_name",
	        PARAMETER_NAME=value,
	        i_input = input_port,
	        o_output = output_port,
	        ...
	    )

	Since the "base" module has a bunch of repeated input and output
	pins that have to be connected to CSRs, the LiteX wrapper uses
	keyword arguments to pass all the arguments.
	"""

	def _make_csr(self, name, csrclass, csrlen, description, num=None):
		""" Add a CSR for a pin `f"{name_{num}"` with CSR type
		`csrclass`. This will automatically handle the `i_` and
		`o_` prefix in the keyword arguments.
		"""

		if name not in self.csrdict.keys():
			self.csrdict[name] = csrlen
		if num is not None:
			name = f"{name}_{num}"

		csr = csrclass(csrlen, name=name, description=description)
		setattr(self, name, csr)

		if csrclass is CSRStorage:
			self.kwargs[f'i_{name}'] = csr.storage
		elif csrclass is CSRStatus:
			self.kwargs[f'o_{name}'] = csr.status
		else:
			raise Exception(f"Unknown class {csrclass}")

	def __init__(self, clk, sdram, platform):
		self.kwargs = {}
		self.csrdict = {}

		for i in range(0,8):
			self._make_csr("dac_sel", CSRStorage, 3, f"Select DAC {i} Output", num=i)
			self._make_csr("dac_finished", CSRStatus, 1, f"DAC {i} Transmission Finished Flag", num=i)
			self._make_csr("dac_arm", CSRStorage, 1, f"DAC {i} Arm Flag", num=i)
			self._make_csr("from_dac", CSRStatus, 24, f"DAC {i} Received Data", num=i)
			self._make_csr("to_dac", CSRStorage, 24, f"DAC {i} Data to Send", num=i)
			self._make_csr("wf_arm", CSRStorage, 1, f"Waveform {i} Arm Flag", num=i)
			self._make_csr("wf_halt_on_finish", CSRStorage, 1, f"Waveform {i} Halt on Finish Flag", num=i)
			self._make_csr("wf_finished", CSRStatus, 1, f"Waveform {i} Finished Flag", num=i)
			self._make_csr("wf_running", CSRStatus, 1, f"Waveform {i} Running Flag", num=i)
			self._make_csr("wf_time_to_wait", CSRStorage, 16, f"Waveform {i} Wait Time", num=i)
			self._make_csr("wf_refresh_start", CSRStorage, 1, f"Waveform {i} Data Refresh Start Flag", num=i)
			self._make_csr("wf_refresh_finished", CSRStatus, 1, f"Waveform {i} Data Refresh Finished Flag", num=i)
			self._make_csr("wf_start_addr", CSRStorage, 32, f"Waveform {i} Data Addr", num=i)

			port = sdram.crossbar.get_port()
			setattr(self, f"wf_sdram_{i}", LiteDRAMDMAReader(port))
			cur_sdram = getattr(self, f"wf_sdram_{i}")

			self.kwargs[f"o_wf_ram_dma_addr_{i}"] = cur_sdram.sink.address
			self.kwargs[f"i_wf_ram_word_{i}"] = cur_sdram.source.data
			self.kwargs[f"o_wf_ram_read_{i}"] = cur_sdram.sink.valid
			self.kwargs[f"i_wf_ram_valid_{i}"] = cur_sdram.source.valid

			self._make_csr("adc_finished", CSRStatus, 1, f"ADC {i} Finished Flag", num=i)
			self._make_csr("adc_arm", CSRStorage, 1, f"ADC {i} Arm Flag", num=i)
			self._make_csr("from_adc", CSRStatus, 32, f"ADC {i} Received Data", num=i)

		self._make_csr("adc_sel_0", CSRStorage, 2, "Select ADC 0 Output")
		self._make_csr("cl_in_loop", CSRStatus, 1, "Control Loop Loop Enabled Flag")
		self._make_csr("cl_cmd", CSRStorage, 8, "Control Loop Command Input")
		self._make_csr("cl_word_in", CSRStorage, 64, "Control Loop Data Input")
		self._make_csr("cl_word_out", CSRStatus, 64, "Control Loop Data Output")
		self._make_csr("cl_start_cmd", CSRStorage, 1, "Control Loop Command Start Flag")
		self._make_csr("cl_finish_cmd", CSRStatus, 1, "Control Loop Command Finished Flag")

		self.kwargs["i_clk"] = clk
		self.kwargs["i_dac_miso"] = platform.request("dac_miso")
		self.kwargs["o_dac_mosi"] = platform.request("dac_mosi")
		self.kwargs["o_dac_sck"] = platform.request("dac_sck")
		self.kwargs["o_dac_ss_L"] = platform.request("dac_ss_L")
		self.kwargs["o_adc_conv"] = platform.request("adc_conv")
		self.kwargs["i_adc_sdo"] = platform.request("adc_sdo")
		self.kwargs["o_adc_sck"] = platform.request("adc_sck")

		with open("csr_bitwidth.json", mode='w') as f:
			import json
			json.dump(self.csrdict, f)

		self.specials += Instance("base", **self.kwargs)

# Clock and Reset Generator
# I don't know how this works, I only know that it does.
# TODO: Connect cpu_reset pin to Verilog modules.
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
		# These source files need to be sorted so that modules
		# that rely on another module come later. For instance,
		# `control_loop` depends on `control_loop_math`, so
		# control_loop_math.v comes before control_loop.v
		platform.add_source("rtl/spi/spi_switch_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_no_write_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_no_read_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_ss_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_ss_no_write_preprocessed.v")
		platform.add_source("rtl/spi/spi_master_ss_no_read_preprocessed.v")
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
				ident = f"Arty-{variant} F4PGA LiteX VexRiscV Zephyr - Upsilon",
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
	soc = CryoSNOM1SoC("a7-100")
	builder = Builder(soc, csr_json="csr.json", compile_software=True)
	builder.build()

if __name__ == "__main__":
	main()
