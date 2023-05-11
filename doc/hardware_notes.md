This document is for recording notes on measurements done on Upslion
running on actual FPGAs.

Commit: `9c2731ad8d794d0b3c46999a40f0064f2b020c69`  
FPGA: Arty A7-100T  
F4PGA commit: `f43bb728b1bd9ef3807ef65bcf6b6629e0fa71f5`

ADCs:

SPI clocks take about 10ns to start going up and down from low voltage.  They
rise to about 500mV in that time. MISO oscillates up and down up to 50mV with
no data present, rising and stays at that until it oscillates down. Should not
be a problem. Probably capacitance/crosstalk. Ringing of about 40mV on clock
and SS.
