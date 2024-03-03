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
		void wait_until_loop_complete();
		void check_data();
		void clear_recv_data();
		WaveformTestbench(int _bailout = 0) : TB<Vwaveform_sim>(_bailout) {}
	private:
		std::vector<uint32_t> send_words;
		std::vector<uint32_t> recv_words;
		void fill_data(int num);
		void posedge() override;
};

void WaveformTestbench::clear_recv_data() {
	recv_words.clear();
}

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
	clear_recv_data();

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
			std::cout << i << ":" << std::hex << was_sent << "!=" << std::hex << recv_words[i % len] << std::endl;
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

void WaveformTestbench::wait_until_loop_complete() {
	if (!mod.do_loop)
		throw std::logic_error("Need to run with do_loop");

	/* wait for the counter to go past the start */
	while (!mod.cntr)
		run_clock();
	/* wait for the counter to return to the start */
	while (mod.cntr)
		run_clock();
}

WaveformTestbench *tb;

void cleanup() {
	delete tb;
}

/* TODO: change around other constants, not just waveform size */
#define NUM_INCRS (3+1)
int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	tb = new WaveformTestbench();
	atexit(cleanup);

	std::cout << "Running single output tests" << std::endl;
	for (int i = 1; i < NUM_INCRS; i++) {
		tb->start_test(64*i, 14, 20, false);
		tb->halt_check(true);
	}

	std::cout << "run loop tests" << std::endl;
	for (int i = 1; i < NUM_INCRS; i++) {
		tb->start_test(64*i, 14, 20, true);

		/* Check that the code will run multiple times */
		for (int j = 0; j < 5; j++) {
			tb->wait_until_loop_complete();
			tb->check_data();
			tb->clear_recv_data();
		}
	}

	std::cout << "Start with single output, then try loop" << std::endl;
	for (int i = 1; i < NUM_INCRS; i++) {
		tb->start_test(64*i, 14, 20, false);

		/* Run the clock for a little bit */
		for (int j = 0; j < 60; j++)
			tb->run_clock();

		tb->mod.do_loop = 1;
		while (tb->mod.cntr)
			tb->run_clock();

		for (int j = 0; j < 5; j++) {
			tb->wait_until_loop_complete();
			tb->check_data();
			tb->clear_recv_data();
		}
	}

	std::cout << "Interrupt single output" << std::endl;
	tb->start_test(1024, 14, 20, false);
	for (int j = 0; j < 60; j++)
		tb->run_clock();

	if (tb->mod.cntr == 0 || tb->mod.cntr == 1024-1)
		throw std::logic_error("Counter should not be this");
	tb->mod.run = 0;
	auto cntr = tb->mod.cntr;
	while (!tb->mod.ready) {
		tb->run_clock();
		if (tb->mod.cntr == cntr + 1)
			throw std::logic_error("Did not stop");
	}

	std::cout << "Test run after interrupt" << std::endl;
	tb->start_test(1024, 14, 20, false);
	tb->halt_check(true);

	return 0;
}
