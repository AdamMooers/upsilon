/* Copyright 2024 (C) Adam Mooers
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

#include <random>
#include <stdexcept>
#include <iostream>
#include <cstdlib>
#include <string>
#include <algorithm>
#include "Vmult32.h"
#include "../testbench.hpp"


class Mult32Testbench : public TB<Vmult32> {
	public:
		void run_test(int32_t, int32_t);
		void dump_inputs();
		void dump_outputs();
		Mult32Testbench(int _bailout = 0) : TB<Vmult32>(_bailout) {}
	private:
		void posedge() override;
};

void Mult32Testbench::posedge() {
}

void Mult32Testbench::run_test(uint32_t multiplicand, uint32_t multiplier) {
	mod.multiplicand = multiplicand;
	mod.multiplier = multiplier;

	// Let the pipeline run through all 3 stages
	for (int j = 0; j<3; j++) {
		this->run_clock();
	}

	uint32_t expected_product = multiplicand*multiplier;

	if (static_cast<int32_t>(mod.product) != expected_product) {
		this->dump_inputs();
		this->dump_outputs();
		throw std::logic_error(
			"Product was not the expected value. (expected mod.product = "+
			std::to_string(expected_product)+")");
	}
}

void Mult32Testbench::dump_inputs() {
	std::cout 
	<< "multiplicand: " <<  static_cast<int32_t>(mod.multiplicand) << std::endl
	<< "multiplier: " << static_cast<int32_t>(mod.multiplier) << std::endl;
}

void Mult32Testbench::dump_outputs() {
	std::cout 
	<< "product: " << static_cast<int32_t>(mod.product) << std::endl;
}

Mult32Testbench *tb;

void cleanup() {
	delete tb;
}

#define NUM_INCRS 1000000
int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);

	tb = new Mult32Testbench();
	atexit(cleanup);

	std::cout << "Checking product math with " << NUM_INCRS << " random inputs." << std::endl;
	auto engine = std::default_random_engine{};
	auto term_dist = std::uniform_int_distribution<int32_t>(-(1 << 19),(1 << 19) - 1);

	for (int i = 1; i < NUM_INCRS; i++) {
		uint32_t multiplicand = term_dist(engine);
		uint32_t multiplier = term_dist(engine);

		tb->run_test(multiplicand, multiplier);
	}

	return 0;
}
