#include <memory>
#include <limits>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <random>
#include <unistd.h>

#include <verilated.h>
#include "control_loop_math_implementation.h"
#include "control_loop_cmds.h"
#include "Vcontrol_loop_sim_top.h"
using ModType = Vcontrol_loop_sim_top;

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

static void set_value(V val, unsigned name) {
	mod->cmd = CONTROL_LOOP_WRITE_BIT | name;
	mod->word_into_loop = val;
	mod->start_cmd = 1;

	do { run_clock(); } while (!mod->finish_cmd);
	mod->start_cmd = 0;
	run_clock();
}

int main(int argc, char **argv) {
	init(argc, argv);
	mod = new ModType;
	Transfer func = Transfer{150, 0, 2, 1.1, 10, -1};

	mod->clk = 0;

	set_value(10000, CONTROL_LOOP_STATUS);
	set_value(0b11010111000010100011110101110000101000111, CONTROL_LOOP_P);
	set_value((V)12 << CONSTS_FRAC, CONTROL_LOOP_I);
	set_value(20, CONTROL_LOOP_DELAY);
	set_value(10000, CONTROL_LOOP_SETPT);
	set_value(1, CONTROL_LOOP_STATUS);

	for (int tick = 0; tick < 10000; tick++) {
		std::cout << tick << std::endl;
		run_clock();
		if (mod->request && !mod->fulfilled) {
			mod->measured_value = func.val(mod->curset);
			mod->fulfilled = 1;
		} else if (mod->fulfilled && !mod->request) {
			mod->fulfilled = 0;
		}

		if (tick == 5000) {
			mod->cmd = CONTROL_LOOP_WRITE_BIT | CONTROL_LOOP_P;
			mod->word_into_loop = 0b010111000010100011110101110000101000111;
			mod->start_cmd = 1;
		}
		if (mod->finish_cmd) {
			mod->start_cmd = 0;
		}
	}

	mod->final();
	delete mod;
	return 0;
}
