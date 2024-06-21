# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

import math
from mmio import *
from AD5791 import *

def configure_dac(dac):
    """
    Resets and enables the output of the given DAC
    :param dac: the dac to configure
    """
    dac.reset()
    dac_settings = {
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
    dac.write_control_register(dac_settings)

# Force these interfaces to the main CPU
# Caution: this can cause unexpected behaviour if another peripheral is using the interface
dac0.PI.v = 0

dac0_driver = AD5791(dac0)
configure_dac(dac0_driver)

# Transfer SPI PI to the waveform generator
dac0.PI.v = 2

num_samples = 512

# Generate sawtooth from 0 to 5 v
sawtooth_wf = [
    dac0_driver.volts_to_dac_lsb(t/float(num_samples)*5.0) 
    for t in range(0, num_samples)
    ]

# Generate a sine wave from -5V to 5V
sine_wf = [
    dac0_driver.volts_to_dac_lsb(5.0*math.sin(t/float(num_samples)*2.0*math.pi)) 
    for t in range(0, num_samples)
    ]

wf0.start(sine_wf, 25, do_loop=True)