# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
from registers import *

class PIPipeline(Immutable):
    def __init__(self, pi_pipeline_pi, regs):
        super().__init__()

        self.pi_pipeline_pi = pi_pipeline_pi
        self.regs = regs

        self.make_immutable()

    def run_pi_pipeline(self, kp, ki, setpoint, actual, integral_input):
        """
        A simple helper function which loads the inputs and returns the outputs
        to document how the pipeline is used. All values are signed (refer to the
        individual register size for 2's complement conversion if necessary)

        Note that the pipeline has an integral input and output. This allows
        the pipeline to be entirely stateless, simplifying the hardware design.
        Whenever a new iteration of the loop is to be run, the output must be
        copied back to the input.

        :param kp: kp parameter of the pi control loop
        :param ki: ki parameter of the pi control loop
        :param setpoint: the desired value of the pi control input
        :param actual: the current value of the pi control input
        :param integral_input: the current integral value
        :return: the output variables of the pipeline
        """
        if self.pi_pipeline_pi.v != 0:
            if not force_control:
                raise Exception("PI Pipeline is not controlled by master")
            self.pi_pipeline_pi.v = 0

        self.regs.kp.v = kp
        self.regs.ki.v = ki
        self.regs.setpoint.v = setpoint
        self.regs.actual.v = actual
        self.regs.integral_input.v = integral_input

        # Now we need to wait 5 clock cycles for the registers to propagate
        # The below loop is not necessary since micropython is slow but helps
        # document the quirk
        for i in range(0,5):
            pass

        return {
            'integral_result':self.regs.integral_result.v,
            'pi_result':self.regs.pi_result.v,
            'pi_result_flags':self.regs.pi_result_flags.v}

    def dump(self):
        """ Dump contents of control registers. """
        return self.regs.dump()
