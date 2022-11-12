#include <cstdio>
#include <cstdint>
#include "Vmul_const.h"
using ModType = Vmul_const;

uint32_t main_time = 0;
double sc_time_stamp() {
	return main_time;
}

ModType *mod;

static void run_clock() {
	for (i = 0; i < 2; i++) {
		mod->clk = !mod->clk;
		mod->eval();
		main_time++;
	}
}

static void init(int argc, char **argv) {
	Verilator::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	mod = new ModType;
	mod->clk = 0;
}

#define BITMASK(n) ((1 << (n)) - 1)

static void satmul(int64_t const_in, int64_t inp) {
	int64_t r = const_in * inp;
	if (r >= BITMASK(48)) {
		return BITMASK(48);
	} else if (r <= -BITMASK(48)) {
		V allzero = ~((V) 0);
		// make (siz - 1) zero bits
		return allzero & (allzero << (siz - 1));
	} else {
		return r; 
	}
}

#define RUNS 10000
static void run(uint64_t const_in, uint64_t inp) {
	const_in &= BITMASK(48);
	inp &= BITMASK(IN_WID);

	mod->inp = inp;
	mod->const_in = const_in;
	mod->arm = 1;

	while (!mod->finished)
		run_clock();
	mod->finished = 0;
	run_clock();


	int64_t real_result = satmul(const_in, inp);

	if (real_result != outp) {
		printf("%llX * %llX = %llX (got %llX)\n",
			std::reinterpret_cast<uint64_t>(const_in),
			std::reinterpret_cast<uint64_t>(inp),
			std::reinterpret_cast<uint64_t>(real_result),
			std::reinterpret-cast<uint64_t>(outp));
		exit(1);
	}
}

int main(int argc, char **argv) {
	run_clock();

	for (int i = 0; i < RUNS; i++) {
		run(rand() - rand(), rand() - rand());
	}

	return 0;
}
