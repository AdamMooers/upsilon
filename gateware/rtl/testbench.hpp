/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
#pragma once
#include <verilated.h>
#include "util.hpp"

/* https://zipcpu.com/blog/2017/06/21/looking-at-verilator.html */
template <class TOP> class TB {
	int tick_count;
	int bailout;

	public:
	TOP mod;

	TB(int _bailout = 0) : mod(), bailout(_bailout) {
		mod.clk = 0;
		tick_count = 0;
	}

	virtual ~TB() {
		mod.final();
	}

	/* This function is called at the positive edge of ever clock
	 * cycle.
	 *
	 * It's intended use is for glue code, like a bus handler.
	 *
	 * The bulk of the simulation code (driving external inputs into the
	 * simulated module and observing results) should be done outside of
	 * this function.
	 */
	virtual void posedge() {}

	void run_clock() {
		mod.clk = !mod.clk;
		mod.eval();
		Verilated::timeInc(1);
		posedge();

		mod.clk = !mod.clk;
		mod.eval();
		Verilated::timeInc(1);
		tick_count++;

		if (bailout > 0 && tick_count >= bailout) {
			exit(1);
		} if (Verilated::gotError()) {
			exit(1);
		}
	}
};
