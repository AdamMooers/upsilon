# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
from registers import *

class PIPipeline(Immutable):
    def __init__(
        self,
        pi_pipeline_controller_pi,
        pi_pipeline_feedback_pi,
        controller_regs,
        feedback_regs):
        super().__init__()

        self.pi_pipeline_controller_pi = pi_pipeline_controller_pi
        self.pi_pipeline_feedback_pi = pi_pipeline_feedback_pi
        self.controller_regs = controller_regs
        self.feedback_regs = feedback_regs

        self.make_immutable()

    def evaluate_pi_pipeline(self, kp, ki, setpoint, actual, integral_input, force=False):
        """
        A simple helper method which loads the inputs and returns the outputs
        to document how the pipeline is used as a whole. This means this method
        plays the parameter config and feedback roles. All values are signed 
        (refer to the individual register size for 2's complement conversion if necessary)

        Note that the pipeline has an integral input and output. This allows
        the pipeline to be stateless (with the exception of a result_valid flag), 
        simplifying the hardware design. Whenever a new iteration of the loop is to 
        be run, the output must be copied back to the input.

        :param kp: kp parameter of the pi control loop
        :param ki: ki parameter of the pi control loop
        :param setpoint: the desired value of the pi control input
        :param actual: the current value of the pi control input
        :param integral_input: the current integral value
        :return: the output variables of the pipeline
        """
        if self.pi_pipeline_controller_pi.v != 0:
            if not force:
                raise Exception("PI Pipeline controller is not controlled by master")
            self.pi_pipeline_controller_pi.v = 0

        if self.pi_pipeline_feedback_pi.v != 0:
            if not force:
                raise Exception("PI Pipeline feedback is not controlled by master")
            self.pi_pipeline_feedback_pi.v = 0

        self.controller_regs.kp.v = kp
        self.controller_regs.ki.v = ki
        self.controller_regs.setpoint.v = setpoint
        self.feedback_regs.actual.v = actual
        self.feedback_regs.integral_input.v = integral_input

        return {
            'integral_result':self.feedback_regs.integral_result.v,
            'pi_result':self.controller_regs.pi_result.v,
            'pi_result_flags':self.feedback_regs.pi_result_flags.v
            }

    def dump(self):
        """ Dump contents of control registers. """
        return self.controller_regs.dump()
