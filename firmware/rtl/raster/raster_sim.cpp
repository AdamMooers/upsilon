#include <memory>
#include <limits>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <random>
#include <unistd.h>

#include <verilated.h>
#include "Vraster_sim.h"
using ModType = Vraster_sim;
ModType *mod;

uint32_t main_time = 0;

static void run_clock() {
	for (int i = 0; i < 2; i++) {
		mod->clk = !mod->clk;
		mod->eval();
		main_time++;
	}
}

static void cleanup_exit() {
	mod->final();
	delete mod;
}

static void init(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	mod = new ModType;
	mod->clk = 0;
	atexit(cleanup_exit);
}

static void init_values() {
	mod->arm = 0;
	mod->max_samples_in = 512;
	mod->max_lines_in = 512;
	/* Settle time is 1 μs */
	mod->settle_time_in = 100;

	mod->dx_in = 17;
	mod->dy_in = 13;
	mod->coord_dac[0] = 0;
	mod->coord_dac[1] = 0;

	for (int i = 0; i < ADCNUM; i++)
		mod->adc_data[i] = 0;
	mod->adc_finished = 0;
	mod->adc_used_in = 0;

	mod->ram_valid = 0;
}

uint32_t *measured_values[ADCNUM];

static void init_measurements() {
	std::default_random_engine generator{};
	std::normal_distribution<> dist{10000, 100};
	std::random_device rd;

	for (int i = 0; i < ADCNUM; i++) {
		generator.seed(rd());
		measured_values[i] = new int32_t[mod->max_lines_in][mod->max_samples_in];
		for (int j = 0; j < mod->max_lines_in; j++) {
			for (int k = 0; k < mod->max_samples_in; k++) {
				measured_values[i][j][k] = dist(generator);
			}
		}
	}
}

static void deinit_measurement() {
	for (int i = 0; i < ADCNUM; i++) {
		delete measured_values[i];
	}
}

static std::array<uint16_t, 1 << MAX_BYTE_WID> fifo;
static uint32_t read_pos, write_pos;

static void handle_ram() {
}

static void handle_adc() {
	static int cntr[ADCNUM] = {0};
	static bool measuring[ADCNUM] = {0};

	for (int i = 0; i < ADCNUM; i++) {
		if (mod->adc_used_in & 1) {
}

int main(int argc, char **argv) {
	init(argc, argv);
	init_values();
	init_measurements();
	run_clock();

	mod->arm = 1;
	while (!mod->finished) {
		run_clock();
		handle_ram();
	}

	return 0;
}
