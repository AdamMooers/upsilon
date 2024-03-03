#include <vector>
#include <random>
#include <stdexcept>
#include <iostream>
#include <cstdlib>
#include "Vwaveform_sim.h"
#include "../testbench.hpp"

class WaveformTestbench : public TB<Vwaveform_sim> {
	public:
		void start_test(int, int, int, bool);
		void halt_check(bool);
		WaveformTestbench(int _bailout) : TB<Vwaveform_sim>(_bailout) {}
	private:
		std::vector<uint32_t> send_words;
		std::vector<uint32_t> recv_words;
		void fill_data(int num);
		void check_data();
		void posedge() override;
};

void WaveformTestbench::posedge() {
	if (!mod.ram_finished) {
		if ((mod.enable & 0b10) != 0) {
			recv_words.push_back(mod.spi_data);
			mod.ram_finished = 1;
		} else if ((mod.enable & 0b01) != 0) {
			mod.ram_data = send_words.at(mod.offset);
			mod.ram_finished = 1;
		}
	} else if ((mod.enable & 0b11) == 0) {
		mod.ram_finished = 0;
	}
}

void WaveformTestbench::fill_data(int num) {
	auto engine = std::default_random_engine{};
	auto distrib = std::uniform_int_distribution<uint32_t>(0,(1 << 20) - 1);

	send_words.clear();
	for (int i = 0; i < num; i++) {
		send_words.push_back(distrib(engine));
	}
}

void WaveformTestbench::check_data() {
	auto len = send_words.size();
	auto recv_size = recv_words.size();

	for (decltype(len) i = 0; i < recv_size; i++) {
		/* SPI message has an extra bit to access DAC register */
		auto was_sent = 1 << 20 | send_words.at(i % len);
		if (was_sent != recv_words.at(i % len)) {
			std::cout << i << ":" << was_sent << "!=" << recv_words[i % len] << std::endl;
			std::exit(1);
		}
	}
}

void WaveformTestbench::start_test(int wform_size, int spi_max_wait, int timer_spacing, bool do_loop) {
	fill_data(wform_size);

	mod.run = 1;
	mod.wform_size = wform_size;
	mod.spi_max_wait = spi_max_wait;
	mod.timer_spacing = timer_spacing;
	mod.do_loop = do_loop;
	run_clock();
}

void WaveformTestbench::halt_check(bool check_for_finish) {
	if (check_for_finish) {
		while (!mod.finished) {
			run_clock();
		}
		mod.run = 0;
		run_clock();
	} else {
		mod.run = 0;
		run_clock();
		while (!mod.ready) {
			run_clock();
		}
	}

	check_data();
}

WaveformTestbench *tb;

void cleanup() {
	delete tb;
}

int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	tb = new WaveformTestbench(100000);
	atexit(cleanup);

	tb->start_test(64, 14, 20, false);
	tb->halt_check(true);

	tb->start_test(64, 14, 20, true);
	tb->halt_check(false);

	return 0;
}
