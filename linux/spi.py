from registers import *

class SPI(RegisterRegion):
    def __init__(self, spiwid, spi_PI, origin, **regs):
        self.spiwid = spiwid
        self.spi_PI = spi_PI
        super().__init__(origin, **regs)

    def send(self, val, force=False):
        if self.spi_PI.v != 0 and not force:
            raise Exception("SPI is controlled by another master")

        self.spi_PI.v = 0

        self.arm.v = 0
        while self.finished_or_ready.v == 0:
            pass

        self.to_slave.v = val
        self.arm.v = 1
        while self.finished_or_ready.v == 0:
            pass

        read_val = self.from_slave.v
        self.arm.v = 0
        return read_val
