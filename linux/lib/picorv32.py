from registers import *

class PicoRV32(Immutable):
    def __init__(self, ram, params, ram_pi):
        """
        :param ram: Instance of FlatArea containing the executable space
          of the PicoRV32.
        :param params: Instance of RegisterRegion. This register region
          contains CPU register information, the enable/disable bit, etc.
        :param ram_pi: Register that controls ram read/write access.
        """
        super().__init__()

        self.ram = ram
        self.ram_pi = ram_pi
        self.params = params

        self.make_immutable()

    def load(self, filename, force=False):
        """ 
        Load file (as bytes) into PicoRV32.
        :param filename: File to load.
        :param force: If True, turn off the PicoRV32 even if it's running.
        """
        if not force and self.params.enable == 1:
            raise Exception("PicoRV32 RAM cannot be modified while running")

        self.params.enable.v = 0
        self.ram_pi.v = 0
        with open(filename, 'rb') as f:
            self.ram.mem8.load(f.read())

    def enable(self):
        """ 
        Start the PicoRV32. 
        """
        self.ram_pi.v = 1
        self.params.enable.v = 1

    def dump(self):
        """ 
        Dump all status information about the PicoRV32. 
        """
        return self.params.dump()

def test_pico(pico, filename):
    pico.load(filename, force=True)
    pico.enable()

    return pico.dump()
