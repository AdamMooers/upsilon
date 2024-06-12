from spi import *

""" This is a simple wrapper for the SPI controller to simplify
    controlling the AD5791.
"""

class AD5791():
    _spi_master = None

    """
    The AD5791 is an 20-bit DAC. We pre-calculate the masks to make reads
    and right slightly faster, more legible, and more portable.
    """
    _DAC_BITS = 20
    _DAC_BIT_MASK = (1 << (_DAC_BITS))-1
    _DAC_SIGN_BIT = 1 << (_DAC_BITS - 1)
    _DAC_MAGNITUDE_BIT_MASK = _DAC_SIGN_BIT-1

    """ Pre bit-shifted registers. The w and r indicate if the write
        bit is set.
    """
    _registers = {
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
        "DACTRI": 3,
        "BIN2sC": 4,
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

    # Set Output
    def set_DAC_register_raw(self):
        pass

    def set_DAC_register_volts(self):
        pass

    def read_DAC_register_lsb(self, twos_comp = False):
        """
        Reads the LSB voltage from the DAC register and fixes the sign

        :param twos_comp: if true, the buffer is considered to be 2s-complement
            and the sign-extended value will be returned. If false, the register is
            considered to be binary offset, and an 

            See the BIN2sC control register
            setting in the datasheet. If false, 
        :return: the raw voltage as stored in the DAC register, possibly sign-extended
        """

        # Send read request
        self._spi_master.send(self._registers["dac_r"])

        # Send an empty buffer to shift out the control register values
        buffer = self._spi_master.send(0x000000)

        # Extract the bits specifying the voltage
        value = buffer & self._DAC_BIT_MASK

        if twos_comp:
            value = (value & self._DAC_MAGNITUDE_BIT_MASK) - (value & self._DAC_SIGN_BIT)
        else:
            # In binary offset mode, the sign bit term is implicit so we add it in here
            value = value - self._DAC_SIGN_BIT

        return value

    def read_DAC_register_volts(self, twos_comp = False):
        """
        Converts the DAC register to volts using the formula specified in the
        datasheet. Note that the formula implicitly assumes the input is binary
        offset encoded (rather than 2's complement) so we convert to binary offset
        and then apply the formula.
        """
        lsb_voltage = self.read_DAC_register_raw(twos_comp)
        lsb_voltage_bit_offset = lsb_voltage + self._DAC_SIGN_BIT

        voltage = (
            ((self.VREF_P-self.VREF_N)/self._DAC_BIT_MASK)*lsb_voltage_bit_offset+
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
        buffer = self._spi_master.send(0x000000)
        decoded_registers = {}

        for reg, offset in self._control_reg_bit_offsets:
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
        for flag in kwargs:
            ctrl_buffer = ctrl_buffer | (1 << self._control_reg_bit_offsets[flag])
        
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