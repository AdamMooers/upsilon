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
import mmio_descr

class CSRHandler:
    """
    Class that wraps the CSR file and fills in registers with information
    from those files.
    """
    def __init__(self, csrjson, registers):
        """
        Reads in the CSR files.

        :param csrjson: Filename of a LiteX "csr.json" file.
        :param registers: A list of ``mmio_descr`` ``Descr``s.
        :param outf: Output file.
        """
        self.registers = registers
        self.csrs = json.load(open(csrjson))

    def update_reg(self, reg):
        """
        Fill in size information from bitwidth json file.

        :param reg: The register.
        :raises Exception: When the bit width exceeds 64.
        """
        regsize = None
        b = reg.blen
        if b <= 8:
            regsize = 8
        elif b <= 16:
            regsize = 16
        elif b <= 32:
            regsize = 32
        elif b <= 64:
            regsize = 64
        else:
            raise Exception(f"unsupported width {b} in {reg.name}")
        setattr(reg, "regsize", regsize)

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
            if not r.rwperm != "read-only":
                self.print(self.fun(r, "write"))

class MicropythonGenerator(InterfaceGenerator):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def get_accessor(self, reg, num):
        addr = self.csr.get_reg_addr(reg, num)
        if reg.regsize in [8, 16, 32]:
            return [f"machine.mem{reg.regsize}[{addr}]"]
        return [f"machine.mem32[{addr + 4}]", f"machine.mem32[{addr}]"]

    def print_write_register(self, indent, varname, reg, num):
        acc = self.get_accessor(reg, num)
        if len(acc) == 1:
            return f'{indent}{acc[0]} = {varname}\n'
        else:
            assert len(acc) == 2
            # Little Endian. See linux kernel, include/linux/litex.h
            return f'{indent}{acc[1]} = {varname} & 0xFFFFFFFF\n' + \
                   f'{indent}{acc[0]} = {varname} >> 32\n'

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

        if reg.num != 1:
            if printed_argument:
                a(', ')
            a('num')
        a('):\n')

        if reg.num == 1:
            a(pfun('\t', 'val', reg, None))
        else:
            for i in range(0,reg.num):
                if i == 0:
                    a(f'\tif ')
                else:
                    a(f'\telif ')
                a(f'num == {i}:\n')
                a(pfun('\t\t', 'val', reg, i))
            a(f'\telse:\n')
            a(f'\t\traise Exception(regnum)\n')
        a('\n')

        return rs

    def header(self):
        return "import machine\n"

if __name__ == "__main__":
   csrh = CSRHandler(sys.argv[1], mmio_descr.registers)
   for r in mmio_descr.registers:
       csrh.update_reg(r)
   MicropythonGenerator(csrh, sys.stdout).print_file()
