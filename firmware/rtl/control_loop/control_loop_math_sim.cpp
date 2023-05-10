/* TODO: add ADC_TO_DAC multiplication and verify */
#include <cstdio>
#include <cstdint>
#include "control_loop_math_implementation.h"
#include "Vcontrol_loop_math.h"
using ModType = Vcontrol_loop_math;

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

#define MASK(n) ((1 << (n)) - 1)
using V = int64_t;

constexpr V per100 = 0b010101011110011000;
constexpr V adc_to_dac = 0b0100000110001001001101110100101111000110101;

static void calculate() {
	/* Multiplication adds an extra CONSTS_FRAC bits to the end,
	 * truncate them. */

	V err_cur = mulsat((V)mod->setpt - (V)mod->measured, adc_to_dac, 64, CONSTS_FRAC);
	V dt = mulsat(per100, (V)mod->cycles << CONSTS_FRAC, 64, CONSTS_FRAC);
	V idt = mulsat(dt, mod->cl_I, 64, CONSTS_FRAC);
	V epidt = mulsat(err_cur << CONSTS_FRAC, mod->cl_P + idt, 64, CONSTS_FRAC);
	V ep = mulsat((V)mod->e_prev << CONSTS_FRAC, mod->cl_P, 64, CONSTS_FRAC);
	V new_adjval = mod->adjval_prev + epidt - ep;

	mod->arm = 1;

	do {
		run_clock();
	} while (!mod->finished);

	mod->arm = 0;
	run_clock();
	run_clock();

	/* Stupid bug: verilator does not sign-extend signed ports */

	printf("err_cur %ld %ld\n", err_cur, sign_extend(mod->e_cur, E_WID));
	printf("dt %ld %ld\n", dt, mod->dt_reg);
	printf("idt %ld %ld\n", idt, mod->idt_reg);
	printf("epidt %ld %ld\n", epidt, mod->epidt_reg);
	printf("ep %ld %ld\n", ep, mod->ep_reg);
	printf("adj %ld %ld\n", new_adjval, mod->adj_val);
}

int main(int argc, char **argv) {
	init(argc, argv);
	mod->arm = 0;
	mod->rst_L = 1;
	run_clock();
	Transfer func = Transfer{150, 0, 2, 1.1, 10, -1};

	/* Initial conditions */
	mod->setpt = 10000;
	mod->cl_P = 0b11010111000010100011110101110000101000111; /* 0.21 */
	mod->cl_I = (V)12 << CONSTS_FRAC;
	mod->cycles = 20; /* dummy number for now */
	mod->e_prev = 0;
	mod->adjval_prev = 0;

	V setting = 100000;

	printf("running\n");
	for (int i = 0; i < 200; i++) {
		mod->measured = func.val(setting);
		mod->stored_dac_val = setting;

		calculate();
		mod->e_prev = mod->e_cur;
		mod->adjval_prev = mod->adj_val;

		/* C++ has no standard arithmetic right shift */
		V adj;

		if ((V)mod->adj_val > 0) {
			adj = mod->adj_val >> CONSTS_FRAC;
		} else {
			adj = -((-mod->adj_val) >> CONSTS_FRAC);
		}

		printf("#%d: setting: %ld, measured: %ld, setpt: %ld, adj: %ld\n", i, setting, mod->measured, mod->setpt, adj);

		setting += adj;
		printf("new_dac_val %ld %ld\n", setting, mod->new_dac_val);
	}

	mod->final();
	delete mod;
	return 0;
}
