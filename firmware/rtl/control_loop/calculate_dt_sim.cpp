#include <cstdio>
#include "control_loop_math_implementation.h"
#include <verilated.h>
#include "Vcalculate_dt.h"
using ModType = Vcalculate_dt;

uint32_t main_time = 0;
double sc_time_stamp() {
	return main_time;
}

ModType *mod;

static void run_clock() {
	for (int i = 0; i < 2; i++) {
		mod->clk = !mod->clk;
		mod->eval();
		main_time++;
	}
}

static void init(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	mod = new ModType;
	mod->clk = 0;
}

int main(int argc, char **argv) {
	int r = 0;

	init(argc, argv);

	for (V i = 1; i < ((1 << 17) - 1); i++) {
		mod->cycles = i;
		mod->arm = 1;
		do { run_clock(); } while (!mod->finished);
		mod->arm = 0;

		V real_dt = calculate_dt(i, DT_WID);
		if (mod->dt != real_dt) {
			printf("(%lld) %lld != %lld\n", i, mod->dt, real_dt);
			r = 1;
			goto end;
		}

		run_clock();
	}

end:
	mod->final();
	delete mod;
	return r;
}
