#include <memory>
#include <cassert>
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

double sc_time_stamp() {
	return main_time;
}

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

#define MAX_VALS 1500
uint32_t vals[MAX_VALS];

static void push(uint32_t v) {
	assert(!mod->full);
	mod->write_dat = v;
	mod->write_enable = 1;
	run_clock();
	mod->write_enable = 0;
	run_clock();
}

static void pop(int i) {
	assert(!mod->empty);
	mod->read_enable = 1;
	run_clock();
	mod->read_enable = 0;
	run_clock();
}

static void push_random(int start, int end) {
	for (int i = start; i < end; i++) {
		vals[i] = rand() & 0xFFFFFFFFFFFF;
		printf("%d\n", i);
		push(vals[i]);
	}
}

static void pop_random(int start, int end) {
	for (int i = start; i < end; i++) {
		pop(i);
		if (mod->read_dat != vals[i]) {
			fprintf(stderr, "expect %u, %u\n", vals[i], mod->read_dat);
			exit(1);
		}
	}
}

int main(int argc, char **argv) {
	init(argc, argv);
	init_values();
	run_clock();
	assert(mod->empty);

	push_random(0, MAX_VALS);
	assert(mod->full);

	pop_random(0, MAX_VALS);
	assert(mod->empty);

	push_random(0, 50);
	pop_random(0, 20);
	push_random(50, 100);
	pop_random(20, 100);

	return 0;
}
