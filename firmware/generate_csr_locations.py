#!/usr/bin/python3
import json
import sys

class CSRGenerator:
	def __init__(self, json_file, registers, f):
		self.registers = registers
		self.j = json.load(open(json_file))
		self.file = f

	def get_reg(self, name, num):
		if num is None:
			regname = f"base_{name}"
		else:
			regname = f"base_{name}_{num}"
		return f'(csr_t) {self.j["csr_registers"][regname]["addr"]}'
	def print(self, *args):
		print(*args, end='', file=self.file)

	def print_array(self, name, num):
		if num == 1:
			self.print(f'csr_t {name} = {self.get_reg(name, None)};\n')
		else:
			self.print(f'csr_t {name}[{num}] = {{', self.get_reg(name, 0))
			for i in range(1,num):
				self.print(',', self.get_reg(name, i))
			self.print('};\n\n')

	def print_registers(self):
		for name,num in self.registers:
			self.print_array(name, num)
	def print_file(self):
		self.print(f'''#pragma once
typedef volatile uint32_t *csr_t;
#define ADC_MAX {adc_num}
#define DAC_MAX {dac_num}
''')
		self.print_registers()

if __name__ == "__main__":
	dac_num = 8
	adc_num = 8

	registers = [
		("dac_sel", dac_num),
		("dac_finished", dac_num),
		("dac_arm", dac_num),
		("from_dac", dac_num),
		("to_dac", dac_num),
		("wf_arm", dac_num),
		("wf_halt_on_finish", dac_num),
		("wf_finished", dac_num),
		("wf_running", dac_num),
		("wf_time_to_wait", dac_num),
		("wf_refresh_start", dac_num),
		("wf_refresh_finished", dac_num),
		("wf_start_addr", dac_num),

		("adc_finished", adc_num),
		("adc_arm", adc_num),
		("from_adc", adc_num),

		("adc_sel_0", 1),
		("cl_in_loop", 1),
		("cl_cmd", 1),
		("cl_word_in", 1),
		("cl_word_out", 1),
		("cl_start_cmd", 1),
		("cl_finish_cmd", 1),
	]

	CSRGenerator("csr.json", registers, sys.stdout).print_file()

