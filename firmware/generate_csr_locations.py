#!/usr/bin/python3
import json

reg_names = {
        "adc" : ("conv", "sck", "sdo"),
        "dac" : ("miso", "ctrl")
}
max_num = 8

def get_reg(j, name, num, pos):
    return j["csr_registers"][f"{name}{num}_{pos}"]["addr"]

j = json.load(open("csr.json"))

print('''#pragma once
         typedef volatile uint32_t *csr_t;
      ''')

for conv in iter(reg_names):
    for reg in reg_names[conv]:
        print(f"const csr_t {conv}_{reg}[{max_num}] =", "{")
        for i in range(0,max_num):
            print("\t", get_reg(j, conv, i, reg), end='')
            if i != max_num - 1:
                print(",")
        print("\n};")
