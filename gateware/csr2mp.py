#!/usr/bin/python3
# Copyright 2023 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
#######################################################################
#
# This file generates a Micropython module "mmio" with functions that
# do raw reads and writes to MMIO registers.
#
# TODO: Devicetree?

import json
import sys

class CSRGenerator:
    def __init__(self, csrjson, bitwidthjson, registers, outf):
        self.registers = registers
        self.csrs = json.load(open(csrjson))
        self.bws = json.load(open(bitwidthjson))
        self.file = outf

    def get_reg(self, name, num=None):
        """ Get the base address of the register. """
        if num is None:
            regname = f"base_{name}"
        else:
            regname = f"base_{name}_{num}"
        return self.csrs["csr_registers"][regname]["addr"]

    def get_accessor(self, name, num=None):
        """ Return a list of Micropython machine.mem accesses that can
        be used to read/write to a MMIO register.

        Since the Micropython API only supports accesses up to the
        natural word size of the processor, multiple accesses must be made
        for 64 bit registers.
        """
        b = self.bws[name]
        if b <= 8:
            return [f'machine.mem8[{self.get_reg(name,num)}]']
        elif b <= 16:
            return [f'machine.mem16[{self.get_reg(name,num)}]']
        elif b <= 32:
            return [f'machine.mem32[{self.get_reg(name,num)}]']
        elif b <= 64:
            return [f'machine.mem32[{self.get_reg(name,num)}]',
                    f'machine.mem32[{self.get_reg(name,num) + 4}]']
        else:
            raise Exception('unsupported width', b)

    def print(self, *args):
        print(*args, end='', file=self.file)

    def print_write_register(self, indent, varname, name, num):
        acc = self.get_accessor(name,num)
        if len(acc) == 1:
            self.print(f'{indent}{acc[0]} = {varname}\n')
        else:
            assert len(acc) == 2
            self.print(f'{indent}{acc[0]} = {varname} & 0xFFFFFFFF\n')
            self.print(f'{indent}{acc[1]} = {varname} >> 32\n')

    def print_read_register(self, indent, varname, name, num):
        acc = self.get_accessor(name,num)
        if len(acc) == 1:
            self.print(f'{indent}return {acc[0]}\n')
        else:
            assert len(acc) == 2
            self.print(f'{indent}return {acc[0]} | ({acc[1]} << 32)\n')

    def print_fun(self, optype, name, regnum, pfun):
        """Print out a read/write function for an MMIO register.
        * {optype} is set to "read" or "write" (the string).
        * {name} is set to the name of the MMIO register, without number suffix.
        * {regnum} is set to the amount of that type oF MMIO register exists.
        * {pfun} is set to {self.print_write_register} or {self.print_read_register}
        """
        self.print(f'def {optype}_{name}(')

        printed_argument = False
        if optype == 'write':
            self.print('val')
            printed_argument = True

        if regnum != 1:
            if printed_argument:
                self.print(', ')
            self.print('num')
        self.print('):\n')

        if regnum == 1:
            pfun('\t', 'val', name, None)
        else:
            for i in range(0,regnum):
                if i == 0:
                    self.print(f'\tif ')
                else:
                    self.print(f'\telif ')
                self.print(f'num == {i}:\n')
                pfun('\t\t', 'val', name, i)
            self.print(f'\telse:\n')
            self.print(f'\t\traise Exception("invalid {name}", regnum)\n')
        self.print('\n')

    def print_file(self):
        self.print('import machine\n')
        for reg in self.registers:
            self.print_fun('read', reg['name'], reg['total'], self.print_read_register)
            if not reg['read_only']:
                self.print_fun('write', reg['name'], reg['total'], self.print_write_register)

if __name__ == "__main__":
   dac_num = 8
   adc_num = 8

   registers = [
        {"read_only": False, "name": "dac_sel", "total": dac_num},
        {"read_only": True, "name": "dac_finished", "total": dac_num},
        {"read_only": False, "name": "dac_arm", "total": dac_num},
        {"read_only": True, "name": "dac_recv_buf", "total": dac_num},
        {"read_only": False, "name": "dac_send_buf", "total": dac_num},
#        {"read_only": False, "name": "wf_arm", "total": dac_num},
#        {"read_only": False, "name": "wf_halt_on_finish", "total": dac_num},
#        {"read_only": True, "name": "wf_finished", "total": dac_num},
#        {"read_only": True, "name": "wf_running", "total": dac_num},
#        {"read_only": False, "name": "wf_time_to_wait", "total": dac_num},
#        {"read_only": False, "name": "wf_refresh_start", "total": dac_num},
#        {"read_only": True, "name": "wf_refresh_finished", "total": dac_num},
#        {"read_only": False, "name": "wf_start_addr", "total": dac_num},

        {"read_only": True, "name": "adc_finished", "total": adc_num},
        {"read_only": False, "name": "adc_arm", "total": adc_num},
        {"read_only": True, "name": "adc_recv_buf", "total": adc_num},
        {"read_only": False, "name": "adc_sel", "total": adc_num},

        {"read_only": True, "name": "cl_in_loop", "total": 1},
        {"read_only": False, "name": "cl_cmd", "total": 1},
        {"read_only": False, "name": "cl_word_in", "total": 1},
        {"read_only": False, "name": "cl_word_out", "total": 1},
        {"read_only": False, "name": "cl_start_cmd", "total": 1},
        {"read_only": True, "name": "cl_finish_cmd", "total": 1},
    ]
   CSRGenerator("csr.json", "csr_bitwidth.json", registers, sys.stdout).print_file()
