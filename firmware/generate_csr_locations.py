#!/usr/bin/python3
import json

reg_names = {
        "adc" : ("conv", "sck", "sdo"),
        "dac" : ("miso", "ctrl")
}
max_num = 8
# TODO: make dependent on adc, dac

def get_reg(j, name, num, pos):
    return j["csr_registers"][f"{name}{num}_{pos}"]["addr"]

j = json.load(open("csr.json"))

print('''
#pragma once
typedef volatile uint32_t *csr_t;
#define ADC_MAX 8
#define DAC_MAX 8
#ifdef CSR_LOCATIONS
''')

for conv in iter(reg_names):
    for reg in reg_names[conv]:
        print(f"static const csr_t {conv}_{reg}[{max_num}] =", "{")
        for i in range(0,max_num):
            print("\t (csr_t)", get_reg(j, conv, i, reg), end='')
            if i != max_num - 1:
                print(",")
        print("\n};")
print("#endif // CSR_LOCATION")
