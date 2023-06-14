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
