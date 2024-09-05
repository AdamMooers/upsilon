# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

import mmio
from AD5791 import AD5791
from picorv32 import *

VREF_N = -10.0
VREF_P = 10.0

settings = {
    "RBUF": 1,
    "OPGND": 0,
    "DACTRI": 0,
    "BIN2sC": 0,
    "SDODIS": 0,
    "LINCOMP0": 0,
    "LINCOMP1": 0,
    "LINCOMP2": 0,
    "LINCOMP3": 0,
}

# Transfer control of DAC0 to the main CPU
mmio.dac0.PI.v = 0
dac = AD5791(mmio.dac0, VREF_N, VREF_P)

dac.reset()
dac.write_DAC_register(0, in_volts=True)
dac.write_control_register(settings)

# Transfer control of DAC0 to the swic
mmio.dac0.PI.v = 1

# Transfer control of ADC0 to the swic
mmio.adc0.PI.v = 1

# Need to fill variables and transfer output
mmio.swic0.params.deltaT.v = 600
mmio.swic0.load('../test.bin')
mmio.swic0.enable()