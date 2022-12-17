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
using ModType = Vram_fifo;
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

static void push(uint32_t v) {
	if (mod->full) {
		fprintf(stderr, "Fifo full at push %d\n", i);
		exit(1);
	}
	mod->in_dat = v;
	mod->write_enable = 1;
	while (!mod->write_fin)
		run_clock();
	mod->write_enable = 0;
	run_clock();
}

static void pop(int i) {
	if (mod->empty) {
		fprintf(stderr, "Fifo empty at pop %d\n", i);
		exit(1);
	}
	mod->read_enable = 1;
	while (!mod->read_fin)
		run_clock();
	mod->read_enable = 0;
	run_clock();
}

#define MAX_VALS 32000/24
uint32_t vals[MAX_VALS];

int main(int argc, char **argv) {
	init(argc, argv);
	init_values();

	mod->rst = 0;
	mod->read_enable = 0;
	mod->write_enable = 0;
	mod->in_dat = 0;
	run_clock();

	/* Simple test */
	for (int i = 0; i < MAX_VALS; i++) {
		vals[i] = rand() & 0xFFFFFFFFFFFF;
		push(vals[i], i);
	}

	for (int i = 0; i < MAX_VALS; i++) {
		pop(i);
		if (mod->out_dat != vals[i]) {
			fprintf(stderr, "expect %u, %u\n", vals[i], mod->out_dat);
			return 1;
		}
	}

	return 0;
}
