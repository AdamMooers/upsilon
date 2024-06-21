# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

import mmio
from picorv32 import *

"""
	// Transfer SPI to pico
	// Load PARAMS_CL_I and PARAMS_CL_P
	// Load Pico with bin
"""

VREF_N = -10.0
VREF_P = 10.0
twosCompEnabled = True

settings = {
    "RBUF": 1,
    "OPGND": 0,
    "DACTRI": 0,
    "BIN2sC": 0 if twosCompEnabled else 1,
    "SDODIS": 0,
    "LINCOMP0": 0,
    "LINCOMP1": 0,
    "LINCOMP2": 0,
    "LINCOMP3": 0,
}

dac = AD5791(mmio.dac0, VREF_N, VREF_P)

dac.reset()
dac.write_control_register(settings)

# Need to fill variables and transfer output
mmio.pico0.load('test.bin')