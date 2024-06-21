# Copyright 2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
import machine

class Immutable:
    """ Makes attributes immutable after calling ``make_immutable``. """

    def __init__(self):
        self._has_init = False

    def make_immutable(self):
        self._has_init = True

    def __setattr__(self, name, val):
        # If the immutable class has not been initialized, then hasattr
        # will return False, and setattr will work as normal.
        if hasattr(self, "_has_init") and self._has_init:
            raise NameError(f'{name}: {self.__class__.__name__} is immutable')

        # Call standard setattr to set class attribute
        super().__setattr__(name, val)

class Accessor(Immutable):
    """ Wraps accesses to a memory region, allowing for byte or word level
        access.
    """

    _accessor = None
    """ Object used to access memory directly. This is either machine.mem8
        or machine.mem32.
    """

    _ind_conv = None
    """ Integer used to convert from addressing in the unit_size to byte
        addressing. This is 1 for ``unit_size=8`` and 4 for ``unit_size=32``.
    """

    def __init__(self, origin, unit_size, size_in_units):
        """
        :param origin: Origin of the memory region.
        :param unit_size: The size in bits of the chunks read by this class.
           Acceptable values are 8 (byte-size) and 32 (word-size).
        :param size_in_units: The accessable size of the memory region in
           units of the specified unit_size.
        """

        self.origin = origin
        self.unit_size = unit_size

        if unit_size == 8:
            self._accessor = machine.mem8
            self._ind_conv = 1
        elif unit_size == 32:
            self._accessor = machine.mem32
            self._ind_conv = 4
        else:
            raise Exception("Accessor can only take unit size 8 or 32")

        self.size_in_units = size_in_units

    def __getitem__(self, i):
        if i < 0 or i >= self.size_in_units:
            raise IndexError(f"Index {i} out of bounds of {self.size_in_units}")
        return self._accessor[self.origin + self._ind_conv*i]

    def __setitem__(self, i, v):
        if i < 0 or i >= self.size_in_units:
            raise IndexError(f"Index {i} out of bounds of {self.size_in_units}")
        self._accessor[self.origin + self._ind_conv*i] = v

    def load(self, arr, start=0):
        """ Load an array into this memory location.

        :param arr: Array where each value in the array can be fit into an
           integer of bitsize unit_size.
        :param start: What offset in the memory region to start writing data
           to.
        """
        for num,b in enumerate(arr,start=start):
            self[num] = b
        for num,b in enumerate(arr,start=start):
            if self[num] != b:
                raise MemoryError(f"{num}: {self[num]} != {b}")

    def dump(self):
        """ 
        :return: an array containing the values in the memory region. 
        """
        return [self[i] for i in range(0, self.size_in_units)]

class FlatArea(Immutable):
    """
    RAM region. RAM regions have no registers inside of them and can be
    accessed at byte-level granularity.
    """

    mem8 = None
    """ Instance of Accessor for byte-level access. """

    mem32 = None
    """ Instance of Accessor for word-level access. """

    def __init__(self, origin, num_words):
        """
        :param origin: Origin of the memory region.
        :param num_words: Number of accessable words in the memory region.
        """
        super().__init__()

        self.mem8 = Accessor(origin, 8, num_words*4)
        self.mem32 = Accessor(origin, 32, num_words)

        self.make_immutable()

class Register(Immutable):
    """ 
    Wraps a single register that has a maxmimum bitlength of 1 word.

    Accesses to registers are done using the ``v`` attribute. Writes to
    ``v`` will write to the underlying memory area, and reads of ``v``
    will read the underlying value.
    """

    loc = None
    """ Location of the register in memory. """

    def __init__(self, loc, **kwargs):
        """
        This class accepts keyword arguments, which are placed in the
        register object as attributes. This can be used to document if the
        register is read-only, etc.
        """
        super().__init__()

        self.loc = loc
        for k in kwargs:
            setattr(self, k, kwargs[k])

        self.make_immutable()

    @property
    def v(self):
        return machine.mem32[self.loc]

    @v.setter
    def v(self, newval):
        machine.mem32[self.loc] = newval

class RegisterRegion(Immutable):
    """ Holds multiple registers that are in the same Wishbone bus region.
    The registers are attributes of the object and are set at instantiation
    time.
    """

    _names = None
    """ List of names of registers in the register region. """

    _origin = None
    """ Origin of the memory region containing the registers. """

    def __init__(self, origin, **regs):
        """
        :param origin: Origin of the memory region containing the registers.
        :param regs: Dictionary of registers that are placed in the object
          as attributes.
        """

        super().__init__()

        self._origin = origin
        self._names = [r for r in regs]

        for r, reg in regs.items():
            setattr(self, r, reg)

        self.make_immutable()

    def dump(self):
        """ Return a dictionary containing the values of all the registers
            in the region.
        """
        return {n:getattr(self,n).v for n in self._names}
