from registers import *

class Waveform(Immutable):
    def __init__(self, ram, ram_pi, regs):
        super().__init__()
        self.ram = ram
        self.ram_pi = ram_pi
        self.regs = regs

        self.make_immutable()

    def run(self, wf, timer_spacing, do_loop = False):
        """ Start waveform with signal.

        :param wf: Array of integers that describe the waveform.
           These are twos-complement 20-bit integers.
        :param timer_spacing: The amount of time to wait between
           points on the waveform.
        :param do_loop: If True, the waveform will repeat.
        """
        self.stop()

        self.ram_pi.v = 0
        self.ram.mem32.load(wf)

        self.regs.wform_width.v = len(wf)
        self.regs.timer_spacing.v = timer_spacing

        self.regs.do_loop.v = do_loop
        self.ram_pi.v = 1
        self.regs.run.v = 1

    def stop(self):
        """ Stop the waveform and wait until it is ready. """
        self.regs.run = 0
        self.regs.do_loop = 0

        while self.regs.finished_or_ready == 0:
            pass

    def force_stop(self):
        self.regs.force_stop = 1
        selff.regs.force_stop = 0

    def dump(self):
        """ Dump contents of control registers. """
        return self.regs.dump()
