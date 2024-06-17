# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

"""
This demo demonstrates how to configure and run an LTC2336 ADC using
Upsilon. To run the demo, first follow the hardware configuration
guide and then transfer it to the booted Upsilon device (using 
`make copy` from the build directory). Finally, run it with the command
`micropython LTC2336_demo.py`.

For hardware, you will need an LTC2336 evaluation board (model# 
DC1908A-LTC2336) connected to the ADC0 SPI bus of the Arty A7. You
will also need two isolated bench supplies for the positive and negative
ADC voltage rails.

1. Verify VCCIO is connected to 3.3V using the JP3 selector.

2. Connect pin 2 of the DC590 port to 3.3V. This prevents contention on
the CNV pin by disconnecting the output from the onboard Max II CPLD.
Note: The 3.3V test output is a convenient place to tie this pin.

3. Make the following connections between the J4 header on the Arty
and the DC1908 board: J4 Pin 0 -> CNV, J4 Pin 1 -> SCK, and J4 Pin 2 -> SDO.
You may want to hook up ground through the Arty but be careful with ground
loops because the DAC analog ground pin, digital ground pin, and signal
ground are all internally connected on the DC1908 board by default.

4. Connect a voltage source through the AIN+ BNC connector. Again,
be on the lookout for potential ground loops.

5. Configure the power supplies for +-16V, shut them off, connect them to
the respective rails on the DC1908 board (double-check that they are correct
since there is no reverse polarity protection).

6. Turn the power supplies on and the demo is ready to run.
"""

import mmio
from LTC_ADC import *

adc = LTC_ADC(mmio.adc0)

while (True):
    print(f"Voltage: {adc.read_voltage()} V")
    time.sleep(2)