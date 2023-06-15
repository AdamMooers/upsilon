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
#include "Vintsat.h"

using dword = int16_t;
using word = int8_t;

double sc_time_stamp() {
	return 0;
}

Vintsat *mod;

static void
run(dword i)
{
	const auto max = std::numeric_limits<word>::max();
	const auto min = std::numeric_limits<word>::min();
	mod->inp = i;
	mod->eval();

	int in = (dword) mod->inp;
	int out = (word) mod->outp;

	if (i <= max && i >= min) {
		if (in != out)
			std::cout << in << "->" << out << std::endl;
	} else {
		if (i < min && out != min)
			std::cout << in << "->" << out << std::endl;
		else if (i > max && out != max)
			std::cout << in << "->" << out << std::endl;
	}
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	mod = new Vintsat;

	dword i;
	for (i = std::numeric_limits<dword>::min();
	     i < std::numeric_limits<dword>::max();
	     i++)
		run(i);
	run(i);

	mod->final();

	delete mod;

	return 0;
}
