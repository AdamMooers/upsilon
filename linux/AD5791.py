
# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

""" 
This is a simple wrapper for the AD5791 DAC intended to be used
on the Upsilon main CPU
"""

class AD5791():
    _spi_master = None

    """
    The AD5791 is an 20-bit DAC. We pre-calculate the masks to make reads
    and right slightly faster, more legible, and more portable.
    """
    _DAC_BITS = 20
    _DAC_ROLLOVER = 1 << _DAC_BITS
    _DAC_BIT_MASK = _DAC_ROLLOVER - 1
    _DAC_SIGN_BIT = 1 << (_DAC_BITS - 1)
    _DAC_MAGNITUDE_BIT_MASK = _DAC_SIGN_BIT - 1

    """ Pre bit-shifted registers. The w and r indicate if the write
        bit is set.
    """
    _registers = {
        "readback": 0x000000,
        "dac_r": 0x900000,
        "dac_w": 0x100000,
        "control_r": 0xA00000,
        "control_w": 0x200000,
        "clearcode_r": 0xB00000,
        "clearcode_w": 0x300000,
        "sw_control_w": 0x400000,
    }

    _control_reg_bit_offsets = {
        "RBUF": 1,
        "OPGND": 2,
        "BIN2sC": 4,
        "DACTRI": 3,
        "SDODIS": 5,
        "LINCOMP0": 6,
        "LINCOMP1": 7,
        "LINCOMP2": 8,
        "LINCOMP3": 9,
    }

    _sw_control_reg_bit_offsets = {
        "RESET": 2,
        "CLR": 1,
        "LDAC": 0,
    }

    def __init__(self, spi_master, VREF_N = -10.0, VREF_P = 10.0):
        """
        :param spi_master: The SPI master which controls the DAC. Refer to soc.py
            for the pinout for each bus.
        
        """
        self._spi_master = spi_master
        self.VREF_N = VREF_N
        self.VREF_P = VREF_P

    def set_DAC_register_lsb(self, lsb_voltage, twos_comp = True):
        """
        Writes the LSB voltage to the DAC register.

        Input -_DAC_SIGN_BIT corresponds to an output voltage of VREF_N
        Input _DAC_SIGN_BIT-1 corresponds to an output voltage of VREF_P

        A step of one LSB corresponds to a change in voltage of (VREF_P-VREF_N)/(2**n-1)
        where n number of number of DAC bits (_DAC_BITS)

        The voltage is clamped from -_DAC_SIGN_BIT to _DAC_SIGN_BIT-1 to prevent
        unexpected outputs if the voltage specified is not in bounds.

        :param lsb_voltage: the LSB voltage to set the DAC output register with
        :param twos_comp: if true, the buffer is considered to be 2s-complement
            and the sign-extended before being written. If false, the register is
            considered to be binary offset and the offset correction is added in.
            This setting is should follow the BIN2sC control register.
        """

        clamped_voltage = max(-self._DAC_SIGN_BIT, min(self._DAC_SIGN_BIT-1, lsb_voltage))

        if twos_comp and clamped_voltage < 0:
            # This will sign-extend with the number of bits available to the DAC
            clamped_voltage += self._DAC_ROLLOVER
        elif not twos_comp:
            clamped_voltage -= self._DAC_SIGN_BIT

        buffer = self._registers["dac_w"] | clamped_voltage

        self._spi_master.send(buffer)

    def set_DAC_register_volts(self, voltage, twos_comp = True):
        """
        Writes the specified voltage, in volts, to the DAC register.

        The voltage is clamped from VREF_N to VREF_P to prevent
        unexpected outputs if the voltage specified is not in bounds.

        :param voltage: the voltage to set the DAC output register with
        :param twos_comp: if true, the buffer is considered to be 2s-complement
            and the sign-extended before being written. If false, the register is
            considered to be binary offset and the offset correction is added in.
            This setting is should follow the BIN2sC control register.
        """

        # This is the ideal transfer function from the AD5791 datasheet inverted
        voltage_as_fraction_of_range = (voltage - self.VREF_N)/(self.VREF_P - self.VREF_N)
        lsb_voltage = int(voltage_as_fraction_of_range*self._DAC_BIT_MASK) - self._DAC_SIGN_BIT

        self.set_DAC_register_lsb(lsb_voltage, twos_comp)

    def read_DAC_register_lsb(self, twos_comp = True):
        """
        Reads the LSB voltage from the DAC register. 
        
        Input -_DAC_SIGN_BIT corresponds to an output voltage of VREF_N
        Input _DAC_SIGN_BIT-1 corresponds to an output voltage of VREF_P

        A step of one LSB corresponds to a change in voltage of (VREF_P-VREF_N)/(2**n-1)
        where n number of number of DAC bits (_DAC_BITS)

        :param twos_comp: if true, the buffer is considered to be 2s-complement
            and the sign-extended value will be returned. If false, the register is
            considered to be binary offset and the offset correction is added in.
            This setting is should follow the BIN2sC control register.
        :return: the raw voltage as stored in the DAC register with sign corrections
        """

        # Send read request
        self._spi_master.send(self._registers["dac_r"])

        # Send an empty buffer to shift out the control register values
        buffer = self._spi_master.send(self._registers["readback"])

        # Extract the bits specifying the voltage
        value = buffer & self._DAC_BIT_MASK

        if twos_comp:
            value = (value & self._DAC_MAGNITUDE_BIT_MASK) - (value & self._DAC_SIGN_BIT)
        else:
            # In binary offset mode, the sign bit term is implicit so we add it in here
            value = value - self._DAC_SIGN_BIT

        return value

    def read_DAC_register_volts(self, twos_comp = True):
        """
        Converts the DAC register to volts using the ideal transfer function
        formula specified in the datasheet (see the DAC register page). Note 
        that the datasheet formula implicitly assumes the input is binary offset
        encoded (rather than 2's complement) so we convert to binary offset
        and then apply the formula.
        """
        lsb_voltage = self.read_DAC_register_lsb(twos_comp)
        lsb_voltage_offset_formatted = lsb_voltage + self._DAC_SIGN_BIT

        voltage = (
            ((self.VREF_P-self.VREF_N)/self._DAC_BIT_MASK)*lsb_voltage_offset_formatted +
            self.VREF_N
        )

        return voltage

    def read_control_register(self):
        """
        Reads and parses the control register into a dictionary (see the AD5791
        datasheet for the names and purposes of flags).

        :return: a dictionary containing the control register fields
        """
        self._spi_master.send(self._registers["control_r"])

        # Send an empty buffer to shift out the control register values
        buffer = self._spi_master.send(self._registers["readback"])
        decoded_registers = {}

        for reg, offset in self._control_reg_bit_offsets.items():
            decoded_registers[reg] = (buffer >> offset) & 1

        return decoded_registers

    def write_control_register(self, **kwargs):
        """
        Sets the specified bits of the control register. Use caution: Any bits not 
        specified are zeroed. To avoid setting bits to 0 unintentionally, this method
        should be paired with read_control_register by first reading, then changing
        any desired bits, and finally writing back to the control register. See the
        datasheet for control register names and purposes.

        :return: the raw response from the DAC
        """

        ctrl_buffer = self._registers["control_w"]
        for flag, value in kwargs.items():
            ctrl_buffer = ctrl_buffer | (value << self._control_reg_bit_offsets[flag])
        
        response = self._spi_master.send(ctrl_buffer)
        return response

    def __set_sw_control_register_bit(self, bit_to_set):
        """
        Sets the given bit of the software control register to the given value.

        :param bit_to_set: bit offset following datasheet convention
            e.g. DB0 corresponds to bit_to_set = 0.
        """
        sw_ctrl_buffer = (
            self._registers["sw_control_w"] | 
            (1 << self._sw_control_reg_bit_offsets[bit_to_set])
        )
        self._spi_master.send(sw_ctrl_buffer)

    def reset(self):
        """
        Reset the DAC through the control register (equivalent to cycling the 
        physical reset pin)
        """
        self.__set_sw_control_register_bit("RESET")

    def clear_dac(self):
        """
        Clears the DAC through the control register (equivalent to cycling the
        CLR pin). The DAC is loaded with the clearcode register value. Consider using
        the CLR pin directly for improved clarity and latency.
        """
        self.__set_sw_control_register_bit("CLR")

    def load_dac(self):
        """
        Updates the DAC output (equivalent to cycling the LDAC pin). Note that
        if the LDAC is held low externally, the DAC output is automatically updated
        (synchronous mode) and so setting this will have no effect. Consider using
        the LDAC pin directly for improved clarity and latency.
        """
        self.__set_sw_control_register_bit("LDAC")