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

import argparse
import json
import sys

class MMIORegister:
    def __init__(self, name, read_only=False, number=1, exntype=None):
        """
        Describes a MMIO register.
        :param name: The name of the MMIO register. This name must be the
            same as the pin name used in ``csr.json``, except for any
            numerical suffix.
        :param read_only: True if the register is read only. Defaults to
            ``False``.
        :param number: The number of MMIO registers with the same name
            and number suffixes. The number suffixes must go from 0
            to ``number - 1`` with no gaps.
        """
        self.name = name
        self.read_only = read_only
        self.number = number
        self.exntype = exntype

def mmio_factory(dac_num, exntype):
    def f(name, read_only=False):
        return MMIORegister(name, read_only, numer=dac_num, exntype=exntype)
    return f
    

class MicroPythonCSRGenerator:
    def __init__(self, csrjson, bitwidthjson, registers, outf):
        """
        This class generates a MicroPython wrapper for MMIO registers.

        :param csrjson: Filename of a LiteX "csr.json" file.
        :param bitwidthjson: Filename of an Upsilon "bitwidthjson" file.
        :param registers: A list of
        """
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

    def print_fun(self, optype, reg, pfun):
        """Print out a read/write function for an MMIO register.

        :param optype: is set to "read" or "write" (the string).
        :param reg: is the dictionary containing the register info.
        :param pfun: is set to {self.print_write_register} or {self.print_read_register}
        """
        name = reg['name']
        regnum = reg['total']
        exntype = reg['exntype]'

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
            self.print(f'\t\traise {exntype}(regnum)\n')
        self.print('\n')

    def print_file(self):
        self.print('import machine\n')
        self.print('class InvalidDACException(Exception):\n\tpass\n')
        self.print('class InvalidADCException(Exception):\n\tpass\n')
        for reg in self.registers:
            self.print_fun('read', reg, self.print_read_register)
            if not reg['read_only']:
                self.print_fun('write', reg, self.print_write_register)

if __name__ == "__main__":
   dac_num = 8
   adc_num = 8
   dac_reg = mmio_factory(dac_num, "InvalidDACException")
   adc_reg = mmio_factory(adc_num, "InvalidADCException")

   registers = [
       dac_reg("dac_sel"),
       dac_reg("dac_finished", read_only=True),
       dac_reg("dac_arm"),
       dac_reg("dac_recv_buf", read_only=True),
       dac_reg("dac_send_buf"),

       adc_reg("adc_finished", read_only=True),
       adc_reg("adc_arm"),
       adc_reg("adc_recv_buf", read_only=True),
       adc_reg("adc_sel"),

       MMIORegister("cl_in_loop", read_only=True),
       MMIORegister("cl_cmd"),
       MMIORegister("cl_word_in"),
       MMIORegister("cl_start_cmd"),
       MMIORegister("cl_finish_cmd", read_only=True),

#        {"read_only": False, "name": "wf_arm", "total": dac_num},
#        {"read_only": False, "name": "wf_halt_on_finish", "total": dac_num},
#        {"read_only": True, "name": "wf_finished", "total": dac_num},
#        {"read_only": True, "name": "wf_running", "total": dac_num},
#        {"read_only": False, "name": "wf_time_to_wait", "total": dac_num},
#        {"read_only": False, "name": "wf_refresh_start", "total": dac_num},
#        {"read_only": True, "name": "wf_refresh_finished", "total": dac_num},
#        {"read_only": False, "name": "wf_start_addr", "total": dac_num},
    ]
   MicroPythonCSRGenerator("csr.json", "csr_bitwidth.json", registers, sys.stdout).print_file()
