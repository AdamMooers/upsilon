from registers import *

class SPI(RegisterRegion):
    def __init__(self, spiwid, origin, **regs):
        self.spiwid = spiwid
        super().__init__(origin, **regs)
