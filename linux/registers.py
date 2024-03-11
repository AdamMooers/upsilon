import machine

class Immutable:
    def __init__(self):
        super().__setattr__("_has_init", False)

    def make_immutable(self):
        self._has_init = True

    def __setattr__(self, name, val):
        if hasattr(self, "_has_init") and self._has_init:
            raise NameError(f'{name}: {self.__class__.__name__} is immutable')
        super().__setattr__(name, val)

class FlatArea(Immutable):
    def __init__(self, origin, num_words):
        super().__init__()

        self.origin = origin
        self.num_words = num_words

        self.make_immutable()

    def __getitem__(self, i):
        if i < 0 or i >= self.num_words*4:
            raise IndexError(f"Index {i} out of bounds of {self.num_words}")
        return machine.mem8[self.origin + i]

    def __setitem__(self, i, v):
        if i < 0 or i >= self.num_words*4:
            raise IndexError(f"Index {i} out of bounds of {self.num_words}")
        machine.mem8[self.origin + i] = v

    def load(self, arr):
        l = len(arr)
        if l >= self.num_words:
            raise IndexError(f"{l} is too large for ram region ({self.num_words})")

        for num, b in enumerate(arr):
            self[num] = b
        for num, b in enumerate(arr):
            if self[num] != b:
                raise MemoryError(f"{num}: {self[num]} != {b}")

    def dump(self):
        o = self.origin
        return [machine.mem32[o + i*4] for i in range(0,self.num_words)]

class Register(Immutable):
    def __init__(self, loc, **kwargs):
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
    def __init__(self, origin, **regs):
        super().__init__()

        self._origin = origin
        self._names = [r for r in regs]

        for r, reg in regs.items():
            setattr(self, r, reg)

        self.make_immutable()

    def dump(self):
        return {n:getattr(self,n).v for n in self._names}
