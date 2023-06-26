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

import collections
import argparse
import json
import sys

class MMIORegister:
    def __init__(self, name, read_only=False, number=1, exntype=None):
        """
        Describes a MMIO register.
        :param name: The name of the MMIO register, excluding the prefix
          defining its module (i.e. ``base_``) and excluding its
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

        # These are filled in by the CSR file.
        self.size = None

def mmio_factory(num, exntype):
    """
    Return a function that simplifies the creation of instances of
    :py:class:`MMIORegister` with the same number and exception type.

    :param num: Number of registers with the same name (minus suffix).
    :param exntype: MicroPython exception type.
    :return: A function ``f(name, read_only=False)``. Each argument is
      the same as the one in the initializer of py:class:`MMIORegister`.
    """
    def f(name, read_only=False):
        return MMIORegister(name, read_only, number=num, exntype=exntype)
    return f

class CSRHandler:
    """
    Class that wraps the CSR file and fills in registers with information
    from those files.
    """
    def __init__(self, csrjson, bitwidthjson, registers):
        """
        Reads in the CSR files.

        :param csrjson: Filename of a LiteX "csr.json" file.
        :param bitwidthjson: Filename of an Upsilon "bitwidthjson" file.
        :param registers: A list of :py:class:`MMIORegister`s.
        :param outf: Output file.
        """
        self.registers = registers
        self.csrs = json.load(open(csrjson))
        self.bws = json.load(open(bitwidthjson))

    def update_reg(self, reg):
        """
        Fill in size information from bitwidth json file.

        :param reg: The register.
        :raises Exception: When the bit width exceeds 64.
        """
        b = self.bws[reg.name]
        if b <= 8:
            reg.size = 8
        elif b <= 16:
            reg.size = 16
        elif b <= 32:
            reg.size = 32
        elif b <= 64:
            reg.size = 64
        else:
            raise Exception(f"unsupported width {b} in {reg.name}")

    def get_reg_addr(self, reg, num=None):
        """
        Get address of register.

        :param reg: The register.
        :param num: Select which register number. Registers without
          numerical suffixes require ``None``.
        :return: The address.
        """
        if num is None:
            regname = f"base_{reg.name}"
        else:
            regname = f"base_{reg.name}_{num}"
        return self.csrs["csr_registers"][regname]["addr"]

class InterfaceGenerator:
    """
    Interface for file generation. Implement the unimplemented functions
    to generate a CSR interface for another language.
    """

    def __init__(self, csr, outf):
        """
        :param CSRHandler csr: 
        :param FileIO outf:
        """
        self.outf = outf
        self.csr = csr

    def print(self, *args):
        """
        Print to the file specified in the initializer and without
        newlines.
        """
        print(*args, end='', file=self.outf)

    def fun(self, reg, optype):
        """ Print function for reads/writes to register. """
        pass
    def header(self):
        """ Print header of file. """
        pass

    def print_file(self):
        self.print(self.header())
        for r in self.csr.registers:
            self.print(self.fun(r, "read"))
            if not r.read_only:
                self.print(self.fun(r, "write"))

class MicropythonGenerator(InterfaceGenerator):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def get_accessor(self, reg, num):
        addr = self.csr.get_reg_addr(reg, num)
        if reg.size in [8, 16, 32]:
            return [f"machine.mem{reg.size}[{addr}]"]
        return [f"machine.mem32[{addr}]", f"machine.mem32[{addr + 4}]"]

    def print_write_register(self, indent, varname, reg, num):
        acc = self.get_accessor(reg, num)
        if len(acc) == 1:
            return f'{indent}{acc[0]} = {varname}\n'
        else:
            assert len(acc) == 2
            return f'{indent}{acc[0]} = {varname} & 0xFFFFFFFF\n' + \
                   f'{indent}{acc[1]} = {varname} >> 32\n'

    def print_read_register(self, indent, varname, reg, num):
        acc = self.get_accessor(reg, num)
        if len(acc) == 1:
            return f'{indent}return {acc[0]}\n'
        else:
            assert len(acc) == 2
            return f'{indent}return {acc[0]} | ({acc[1]} << 32)\n'

    def fun(self, reg, optype):
        rs = ""
        def a(s):
            nonlocal rs
            rs = rs + s
        a(f'def {optype}_{reg.name}(')

        printed_argument = False
        if optype == 'write':
            a('val')
            printed_argument = True
            pfun = self.print_write_register
        else:
            pfun = self.print_read_register

        if reg.number != 1:
            if printed_argument:
                a(', ')
            a('num')
        a('):\n')

        if reg.number == 1:
            a(pfun('\t', 'val', reg, None))
        else:
            for i in range(0,reg.number):
                if i == 0:
                    a(f'\tif ')
                else:
                    a(f'\telif ')
                a(f'num == {i}:\n')
                a(pfun('\t\t', 'val', reg, i))
            a(f'\telse:\n')
            a(f'\t\traise {r.exntype}(regnum)\n')
        a('\n')

        return rs

    def header(self):
        return """import machine
class InvalidDACException(Exception):
    pass
class InvalidADCException(Exception):
    pass
"""

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
   ]
   csrh = CSRHandler(sys.argv[1], sys.argv[2], registers)
   for r in registers:
       csrh.update_reg(r)
   MicropythonGenerator(csrh, sys.stdout).print_file()
