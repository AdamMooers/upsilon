/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
#include <memory>
#include <limits>
#include <cstdint>
#include <iostream>
#include <verilated.h>
#include "Vboothmul.h"

using word = int16_t;
using dword = int32_t;

constexpr word minint = std::numeric_limits<word>::min();
constexpr word maxint = std::numeric_limits<word>::max();

uint32_t main_time = 0;

double sc_time_stamp() {
	return main_time;
}

Vboothmul *mod;

static void run_clock() {
	mod->clk = !mod->clk;
	mod->eval();
	main_time++;

	mod->clk = !mod->clk;
	mod->eval();
	main_time++;
}

static void run(word i, word j) {
	// Processor is twos-compliment
	mod->a1 = i;
	mod->a2 = j;
	mod->arm = 1;

	while (!mod->fin)
		run_clock();

	dword expected = (dword) i * (dword) j;
	if (mod->outn != expected) {
		std::cout << i << "*" << j << "=" << expected
		          << "(" << mod->outn << ")" << std::endl;
	}

	mod->arm = 0;
	run_clock();
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	// Verilated::traceEverOn(true);
	mod = new Vboothmul;

	mod->clk = 0;
	mod->arm = 0;
	run_clock();

	run(minint, minint);
	run(minint, maxint);
	run(maxint, minint);
	run(maxint, maxint);

	for (word i = -20; i < 20; i++) {
		for (word j = - 20; j < 20; j++) {
			run(i, j);
		}
	}

	mod->final();

	delete mod;
	std::cout << "done" << std::endl;

	return 0;
}
