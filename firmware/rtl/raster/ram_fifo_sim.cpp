#include <memory>
#include <limits>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <random>
#include <unistd.h>

#include <verilated.h>
#include "Vram_fifo.h"
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

static void init_values() {
	mod->rst = 0;
	mod->read_enable = 0;
	mod->write_enable = 0;
	mod->write_dat = 0;
}

#define MAX_VALS 32000/24
uint32_t vals[MAX_VALS];

static void push(uint32_t v) {
	mod->write_dat = v;
	mod->write_enable = 1;
	run_clock();
	mod->write_enable = 0;
	run_clock();
}

static void pop(int i) {
	mod->read_enable = 1;
	run_clock();
	mod->read_enable = 0;
	run_clock();
}

int main(int argc, char **argv) {
	init(argc, argv);
	init_values();
	run_clock();

	/* Simple test */
	for (int i = 0; i < MAX_VALS; i++) {
		vals[i] = rand() & 0xFFFFFFFFFFFF;
		push(vals[i]);
	}

	for (int i = 0; i < MAX_VALS; i++) {
		pop(i);
		if (mod->read_dat != vals[i]) {
			fprintf(stderr, "expect %u, %u\n", vals[i], mod->read_dat);
			return 1;
		}
	}

	return 0;
}
