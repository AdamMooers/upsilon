#include <vector>
#include "Vwaveform_sim.h"
#include "../testbench.hpp"

class WaveformTestbench : public TB<Vwaveform_sim> {
private:
	void refresh_posedge();
	void spi_posedge();
public:
	std::array<uint32_t, WORD_AMNT> ram_refresh_data;
	int cur_ind;
	void posedge() override;
	void refresh_data();
	WaveformTestbench(int _bailout = 0) : TB<Vwaveform_sim>(_bailout)
	                                    , ram_refresh_data{}
	                                    , cur_ind{0} {}
};

void WaveformTestbench::refresh_data() {
	for (size_t i = 0; i < WORD_AMNT; i++) {
		uint32_t val = mask_extend(rand(), 20);
		ram_refresh_data[i] = val;
		mod.backing_store[i*2] = val & 0xFFFF;
		mod.backing_store[i*2+1] = val >> 16;
	}

	mod.refresh_start = 1;
	mod.start_addr = 0x12340;
}

void WaveformTestbench::refresh_posedge() {
	if (mod.refresh_finished) {
		mod.refresh_start = 0;
	}
}

void WaveformTestbench::spi_posedge() {
	if (mod.finished) {
		mod.rdy = 0;
		// Check for proper DAC register.
		my_assert(mod.from_master >> 20 == 0x1, "%d", mod.from_master >> 20);
		uint32_t val = mask_extend(mod.from_master & 0xFFFFF, 20);
		my_assert(val == ram_refresh_data[cur_ind], "(%d) %X != %X",
		          cur_ind, val, ram_refresh_data[cur_ind]);
		cur_ind++;
		if (cur_ind == WORD_AMNT)
			cur_ind = 0;
	} else if (!mod.finished && !mod.rdy) {
		mod.rdy = 1;
	}
}

void WaveformTestbench::posedge() {
	refresh_posedge();
	spi_posedge();
}

WaveformTestbench *tb;

int main(int argc, char *argv[]) {
	int j = 0;
	Verilated::commandArgs(argc, argv);
	// Verilated::traceEverOn(true);
	Verilated::fatalOnError(false);

	tb = new WaveformTestbench();
	tb->mod.rdy = 1;
	tb->refresh_data();
	tb->mod.time_to_wait = 10;
	tb->mod.halt_on_finish = 1;
	tb->mod.arm = 1;

	do {
		tb->run_clock();
	} while (!tb->mod.refresh_finished);

	printf("first run\n");
	do {
		tb->run_clock();
	} while (!tb->mod.waveform_finished);
	printf("waveform finished\n");

	tb->mod.halt_on_finish = 0;
	tb->mod.arm = 0;
	tb->run_clock();
	tb->mod.arm = 1;
	tb->mod.halt_on_finish = 1;

	printf("second run\n");
	do {
		tb->run_clock();
	} while (!tb->mod.waveform_finished);

	tb->mod.rdy = 0;
	tb->mod.halt_on_finish = 0;
	tb->mod.refresh_start = 1;
	do {
		tb->run_clock();
	} while (!tb->mod.refresh_finished);

	tb->mod.rdy = 1;
	tb->mod.halt_on_finish = 1;

	printf("third run\n");
	do {
		tb->run_clock();
	} while (!tb->mod.waveform_finished);

	delete tb;
	return 0;
}
