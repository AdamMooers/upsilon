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

To run this demo, you will need an AD5791 evaluation board (model# 
EVAL-AD5791SDZ) connected to the DAC0 SPI bus of the Arty A7. This
guide uses two isolated bench power supplies for the positive and negative
DAC voltage rails although it could be adapted to work with the evaluation
board's internal ADP5070 power supply as well.

With USB disconnected, add the following interconnects between the 
Arty PMOD A port and the AD5791 evaluation board's J12 header. 
PMOD A numbers are from right to left and top to bottom with numbering 
starting at 1. This demo only uses the top row of PMOD A.

        | J12 Header    | PMOD A
SS      |   SYNC        | Pin 1
MOSI    |   SDIN        | Pin 2
MISO    |   SDO         | Pin 3
SCK     |   SCLK        | Pin 4
GND     |   DGND        | Pin 5
IOVCC   |   IOVCC       | Pin 6

Next, configure the jumpers on the board to work with an external power
supply:

LK1: Slot A (datasheet recommends this always but it should not 
     matter because we are using IOVCC through LK8 for digital power)
LK2: Removed
LK3: Inserted (to hold ~LDAC low because we want the output 
     to update synchronously i.e. directly after SYNC is brought high)
LK4: Removed otherwise board is in reset mode
LK5: Inserted (by datasheet recommendation although it should matter
     because we are using IOVCC through LK8 for digital power)
LK6: Not applicable
LK7: Not applicable
LK8: Slot A (so that we can use IOVCC on J12 for digital power)
LK9: Slot A (to use VSS on J13 as the negative rail)
LK10: Slot A (to use VDD on J13 as the positive rail)
LK11: Removed (otherwise the DAC register is held at the clearcode value)

Connect the positive and negative power supplies in series and set them
both to 16V. Turn both power supplies off and connect the negative rail to 
VSS on terminal J13 and the positive rail to VDD on terminal J13. Leave the
power supplies isolated to eliminate ground loops through DGND since DGND
is internally connected with the analog ground on the evaluation board.
"""