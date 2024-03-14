class RandomGenerator:
    # XorShift
    def __init__(self, seed=2463534242):
        self.seed = seed

    def __call__(self):
        self.seed = self.seed ^ ((self.seed << 13) & 0xFFFFFFFF)
        self.seed = self.seed ^ ((self.seed >> 17) & 0xFFFFFFFF)
        self.seed = self.seed ^ ((self.seed <<  5) & 0xFFFFFFFF)
        return self.seed
