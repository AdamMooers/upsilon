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

with open('csr.json', 'rt') as f:
    csrs = json.load(f)

print("from micropython import const")

for key in csrs["csr_registers"]:
    if key.startswith("pico0"):
        print(f'{key} = const({csrs["csr_registers"][key]["addr"]})')

with open('soc_subregions.json', 'rt') as f:
    subregions = json.load(f)

for key in subregions:
    if subregions[key] is None:
        print(f'{key} = const({csrs["memories"][key]["base"]})')
    else:
        print(f'{key}_base = const({csrs["memorys"][key]["base"]})')
        print(f'{key} = {subregions[key].__repr__()}')
