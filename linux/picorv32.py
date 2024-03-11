from registers import *

class PicoRV32(Immutable):
    def __init__(self, ram, params, ram_pi):
        super().__init__()

        self.ram = ram
        self.ram_pi = ram_pi
        self.params = params

        self.make_immutable()

    def load(self, filename, force=False):
        if not force and self.params.enable == 1:
            raise Exception("PicoRV32 RAM cannot be modified while running")

        self.params.enable.v = 0
        self.ram_pi.v = 0
        with open(filename, 'rb') as f:
            self.ram.load(f.read())

    def enable(self):
        self.ram_pi.v = 1
        self.params.enable.v = 1

    def dump(self):
        return self.params.dump()

def test_pico(pico, filename, cl_I):
    pico.params.cl_I.v = cl_I

    pico.load(filename, force=True)
    pico.enable()

    return pico.dump()
