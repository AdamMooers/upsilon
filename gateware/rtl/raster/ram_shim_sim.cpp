/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
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
#include "ram_shim_cmds.h"

#include "Vram_shim.h"
using ModType = Vram_shim;
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

	char *seed = getenv("RANDOM_SEED");
	if (seed) {
		unsigned long i = strtoul(seed, NULL, 10);
		srand((unsigned int)i);
	}
}

static void init_values() {
	mod->rst = 0;
	mod->cmd_data = 0;
	mod->cmd = 0;
	mod->cmd_active = 0;

	mod->data = 0;
	mod->data_commit = 0;
	mod->valid = 0;
}

using V = uint32_t;

// Verilator makes all ports unsigned, even when marked as signed in
// Verilog.
V sign_extend(V x, unsigned len) {
	// if high bit is 1
	if (x >> (len - 1) & 1) {
		// This mask selects all bits below the highest bit.
		// By inverting it, it selects the highest bit, and all
		// higher bits that must be sign extended.
		V mask = (1 << len) - 1;
		// Set all high bits to 1. The mask has all bits lower
		// than the highest bit 0, so the bits in "x" pass through.
		return ~mask | x;
	} else {
		return x;
	}
}
#define MASK_TO(x,n) ((x) & ((1 << (n)) - 1))

/* Test memory buffering and memory interface.
 * The memory interface takes 16 bits integers at a time. The ram interface
 * runs slower than the insertion loop, to test buffering.
 *
 * The values given to the Verilog module are also stored in memory as
 * 32 bit integers. These are compared with the memory that simulates the
 * RAM interface.
 */

#define MEMORY_LEN 1000 // How many 32 bit integers
#define MEMORY_LEN_16BIT MEMORY_LEN*2 // How many 16 bit parts
#define MEMORY_START 0x10241024
static std::array<uint16_t, MEMORY_LEN_16BIT> backing_memory;
static std::array<bool, MEMORY_LEN_16BIT> backing_memory_accessed;
#define MEMORY_WAIT_TIME 50

static void handle_memory() {
	// Memory counter is used to simulate RAM delay.
	// TODO; random ram delay
	static uint32_t memory_counter = 0;

	if (mod->write) {
		if (memory_counter == MEMORY_WAIT_TIME) {
			mod->valid = 1;
			return;
		}

		if (memory_counter == 0) {
			uint32_t memory_access_ind = 0;

			assert(mod->addr >= MEMORY_START);
			memory_access_ind = mod->addr - MEMORY_START;

			// Addresses are bytes, but writes are always 16 bits.
			// Ensure we are writing to a 16 bit boundary.
			assert(memory_access_ind % 2 == 0);
			memory_access_ind /= 2;

			// Check to make sure that the RAM interface is not overwriting
			// memory locations. For now, it should not do that.
			assert(!backing_memory_accessed[memory_access_ind]);
			backing_memory_accessed[memory_access_ind] = true;

			assert(memory_access_ind < MEMORY_LEN_16BIT);
			backing_memory[memory_access_ind] = mod->word;
			// printf("RAM end: %x @ %d\n", backing_memory[memory_access_ind], memory_access_ind);
		}
		memory_counter++;
	} else {
		mod->valid = 0;
		assert(memory_counter == MEMORY_WAIT_TIME || memory_counter == 0);
		memory_counter = 0;
	}
}

static void init_memory() {
	mod->cmd_data = MEMORY_LEN;
	mod->cmd = RAM_SHIM_WRITE_LEN;

	mod->cmd_active = 1;
	while (!mod->cmd_finished)
		run_clock();
	mod->cmd_active = 0;
	run_clock();

	mod->cmd_data = MEMORY_START;
	mod->cmd = RAM_SHIM_WRITE_LOC;

	mod->cmd_active = 1;
	while (!mod->cmd_finished)
		run_clock();
	mod->cmd_active = 0;
	run_clock();
}

static std::array<uint32_t, MEMORY_LEN> generated_memory;
constexpr int CYCLE_WAIT = 10;

int main(int argc, char **argv) {
	init(argc, argv);
	init_values();
	init_memory();

	/* Every CYCLE_WAIT cycles, push one value to RAM.
	 * This should be smaller than the amount of time it takes for
	 * the ram to "process" the added value.
	 */
	int i = 0;
	int cntr = 0;
	while (i < MEMORY_LEN) {
		run_clock();
		handle_memory();

		if (cntr == CYCLE_WAIT) {
			if (!mod->finished && !mod->data_commit) {
				generated_memory[i] = sign_extend(MASK_TO(rand(), 24), 24);
				// printf("Sending: %d, %x\n", i, generated_memory[i]);
				mod->data = generated_memory[i];
				mod->data_commit = 1;
			} else if (mod->finished && mod->data_commit) {
				mod->data_commit = 0;
				i++;
				cntr = 0;
			}
		} else {
			cntr++;
		}
	}

	fprintf(stderr, "Waiting on bram\n");
	while (!mod->fifo_steady) {
		run_clock();
		handle_memory();
	}
	handle_memory();
	fprintf(stderr, "Bram complete\n");

	for (i = 0; i < MEMORY_LEN_16BIT; i+=2) {
		uint32_t nv = (uint32_t)backing_memory[i+1] << 16 | backing_memory[i];
		if (generated_memory[i/2] != nv) {
			fprintf(stderr, "%d: %x != %x\n", i, generated_memory[i/2], nv);
			exit(1);
		}
	}

	return 0;
}
