#!/usr/bin/python3
# Copyright 2023 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
#######################################################################
#
# This file generates memory locations
#
# TODO: Devicetree?

import collections
import argparse
import json
import sys
import mmio_descr

with open(sys.argv[1], 'rt') as f:
    j = json.load(f)

print("from micropython import const")

for key in j["csr_registers"]:
    if key.startswith("pico0"):
        print(f'{key} = const({j["csr_registers"][key]["addr"]})')

print(f'pico0_ram = const({j["memories"]["pico0_ram"]["base"]})')
print(f'pico0_dbg_reg = const({j["memories"]["pico0_dbg_reg"]["base"]})')
