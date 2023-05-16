#!/usr/bin/python3
import json
import sys

"""
This file uses csr.json and csr_bitwidth.json and writes functions
that handle reads and writes to MMIO.
"""

class CSRGenerator:
	def __init__(self, csrjson, bitwidthjson, registers, outf, dacmax, adcmax):
		self.registers = registers
		self.csrs = json.load(open(csrjson))
		self.bws = json.load(open(bitwidthjson))
		self.file = outf
		self.dacmax = dacmax
		self.adcmax = adcmax

	def get_reg(self, name, num):
		if num is None:
			regname = f"base_{name}"
		else:
			regname = f"base_{name}_{num}"
		return self.csrs["csr_registers"][regname]["addr"]

	def get_bitwidth_type(self, name):
		b = self.bws[name]
		if b <= 8:
			return 8
		elif b <= 16:
			return 16
		elif b <= 32:
			return 32
		elif b <= 64:
			return 64
		else:
			raise Exception('unsupported width', b)

	def print(self, *args):
		print(*args, end='', file=self.file)

	def print_write_fun(self, name, regnum):
		typ = self.get_bitwidth_type(name)
		self.print('static inline void\n')
		self.print(f'write_{name}(uint{typ}_t v')

		if regnum != 1:
			self.print(f', int num')
		self.print(')\n{\n')

		if regnum != 1:
			self.print('\t', f'static const uintptr_t loc[{regnum}]', '= {\n')
			self.print('\t\t', self.get_reg(name,0), '\n')
			for i in range(1,regnum):
				self.print('\t\t,', self.get_reg(name, i), '\n')
			self.print('\t};\n')
			self.print('''
	if (num < 0 || num >= ARRAY_SIZE(loc)) {
		LOG_ERR("invalid location %d", num);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}
''')
		self.print('\t', f'litex_write{typ}(v, {"loc[num]" if regnum != 1 else self.get_reg(name, None)});', '\n}\n\n')

	def print_read_fun(self, name, regnum):
		typ = self.get_bitwidth_type(name)
		self.print(f'static inline uint{typ}_t\nread_{name}')

		if regnum != 1:
			self.print(f'(int num)', '\n{\n')
		else:
			self.print('(void)\n{\n')

		if regnum != 1:
			self.print('\t', f'static const uintptr_t loc[{regnum}]', '= {\n')
			self.print('\t\t', self.get_reg(name,0), '\n')
			for i in range(1,regnum):
				self.print('\t\t,', self.get_reg(name, i), '\n')
			self.print('\t};\n')
			self.print('''
	if (num < 0 || num >= ARRAY_SIZE(loc)) {
		LOG_ERR("invalid location %d", num);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}
''')
		self.print('\t', f'return litex_read{typ}({"loc[num]" if regnum != 1 else self.get_reg(name, None)}', ');\n}\n\n')

	def print_file(self):
		self.print('''
#pragma once

static inline void litex_write64(uint64_t value, unsigned long addr)
{
#if CONFIG_LITEX_CSR_DATA_WIDTH >= 32
	sys_write32(value >> 32, addr);
	sys_write32(value, addr + 0x4);
#else
# error Unsupported CSR data width
#endif
}

''')
		self.print('#define DAC_MAX', self.dacmax, '\n')
		self.print('#define ADC_MAX', self.adcmax, '\n')
		for reg in self.registers:
			self.print_read_fun(reg[1],reg[2])
			if not reg[0]: #read only
				self.print_write_fun(reg[1],reg[2])

if __name__ == "__main__":
	dac_num = 8
	adc_num = 8

	registers = [
		# Read-only, name, number
		(False, "dac_sel", dac_num),
		(True, "dac_finished", dac_num),
		(False, "dac_arm", dac_num),
		(True, "from_dac", dac_num),
		(False, "to_dac", dac_num),
		(False, "wf_arm", dac_num),
		(False, "wf_halt_on_finish", dac_num),
		(True, "wf_finished", dac_num),
		(True, "wf_running", dac_num),
		(False, "wf_time_to_wait", dac_num),
		(False, "wf_refresh_start", dac_num),
		(True, "wf_refresh_finished", dac_num),
		(False, "wf_start_addr", dac_num),

		(True, "adc_finished", adc_num),
		(False, "adc_arm", adc_num),
		(True, "from_adc", adc_num),

		(False, "adc_sel", adc_num),
		(True, "cl_in_loop", 1),
		(False, "cl_cmd", 1),
		(False, "cl_word_in", 1),
		(False, "cl_word_out", 1),
		(False, "cl_start_cmd", 1),
		(True, "cl_finish_cmd", 1),
	]

	CSRGenerator("csr.json", "csr_bitwidth.json", registers, sys.stdout, dac_num, adc_num).print_file()

