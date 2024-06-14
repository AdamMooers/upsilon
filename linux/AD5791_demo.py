# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

"""
This demo demonstrates how to configure and run an AD5791 DAC using
Upsilon. To run the demo, first follow the hardware configuration
guide and then transfer it to the booted Upsilon device (using 
`make copy` from the build directory). Finally, run it with the command
`micropython AD5791_demo.py`.

For hardware, you will need an AD5791 evaluation board (model# 
EVAL-AD5791SDZ) connected to the DAC0 SPI bus of the Arty A7. This
guide uses two isolated bench power supplies for the positive and negative
DAC voltage rails although it could be adapted to work with the evaluation
board's internal ADP5070 power supply as well (see the evaluation board
datasheet for details on how to set this up).

First, configure the jumpers on the board to work with an external power
supply:

LK1: Slot A (datasheet recommends this always but it should not 
     matter because we are using IOVCC through LK8 for digital power)
LK2: Removed because we are going to use the same supply for IOVCC and
     VCC and we don't need the internal analog rails. The ADP7118 LDO
     regulator for VCC is unnecessary and won't operate off 3.3V anyway.
LK3: Inserted (to hold ~LDAC low because we want the output 
     to update synchronously i.e. directly after SYNC is brought high)
LK4: Removed otherwise board is in reset mode
LK5: Inserted to bypass the ADP7118 regulator for VCC (see LK2 notes)
LK6: Not applicable
LK7: Not applicable
LK8: Slot C (so that we can use the same supply for VCC and IOVCC)
LK9: Slot A (to use VSS on J13 as the negative rail)
LK10: Slot A (to use VDD on J13 as the positive rail)
LK11: Removed (otherwise the DAC register is held at the clearcode value)

Next, with USB disconnected, add the following interconnects between the 
Arty PMOD A port and the AD5791 evaluation board's J12 header. PMOD A pin
numbers are from right to left and top to bottom with numbering 
starting at 1. This demo only uses the top row of PMOD A.

        | J12 Header    | PMOD A
SS      |   ~SYNC       | Pin 1
MOSI    |   SDIN        | Pin 2
MISO    |   SDO         | Pin 3
SCK     |   SCLK        | Pin 4
GND     |   DGND        | Pin 5

Connect the Pin 6 of the PMOD A header to VCC on the J11 terminal.

Connect the positive and negative power supplies in series and set them
both to 16V. Turn both power supplies off and connect the negative rail (-16V)
to VSS on terminal J13, ground through GND of terminal J13, and
the positive rail (+16V) to VDD on terminal J13. Leave the power supplies isolated
to eliminate ground loops through DGND since DGND is internally connects
with both earth ground through the USB connection on the ARTY board and
the analog ground (J13 GND) on the evaluation board.

Turn on the positive bench power supply (VDD) followed by the negative
bench power supply (connected to VSS). Next, connect USB to the ARTY board.
This order ensures that VCC is powered after VDD, which, according to the
datasheet, ensures that the DAC starts in a known good state. Finally,
flash the ARTY, boot Linux, and follow the guide for running at the top.

Outputs are broken out on the VO and VO_buf SMB connectors at the top edge
of the board. VO is directly connected to the DAC's output whereas
VO_buf is run through a unity gain amplifier.
"""

import mmio
from AD5791 import *

VREF_N = -10.0
VREF_P = 10.0

dac = AD5791(mmio.dac0, VREF_N, VREF_P)

# Although not strictly necessary if the power up sequence is handled correctly,
# this ensures that the DAC is in a known good state
dac.reset()

"""
Set up the DAC with the following configuration. See the datasheet for
more details on what these flags mean.

RBUF:     1 to enable an external buffer amplifier as configured in fig. 52
          of the AD5791 datasheet. This is the configuration used on the 
          evaluation board.
OPGND:    0 to place the DAC in normal mode. On reset, this is set to 1 which means
          the output is clamped to ground through a 6kOhm resistor.
DACTRI:   0 to take the DAC out of tristate mode (connects the DAC to the
          output pin)
BIN/2sC:  0 to use 2's complement encoding (this is the default)
SDODIS:   0 to enable the SDO pin (this is the default)
LIN COMP: All 0 since the evaluation board is using +-10V references through the
          ADR445 reference board
"""

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

dac.write_control_register(**settings)

"""
Checking the response from the settings register provides a sanity
check that the hardware is configured correctly. Likely causes for
this assertion failing include power being off, the bus being incorrectly
wired, or the clock frequency being too high.
""" 
settingsEcho = dac.read_control_register()
assert settingsEcho == settings, "The echoed settings did not match"

dac.set_DAC_register_volts(5.0, twosCompEnabled)