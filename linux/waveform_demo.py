# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from mmio import *
from AD5791 import *

CLK_FREQ = 100.0e6

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

# Generate sawtooth from -1 to 1 v
sawtooth_wf = [dac0_driver.volts_to_dac_lsb(((t%2)*2.5)) for t in range(0, 128)]

wf0.start(sawtooth_wf, 1, do_loop=False)