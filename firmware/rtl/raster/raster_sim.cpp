#include <limits>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <cstdarg>
#include <iostream>
#include <unistd.h>
#include <verilated.h>

#include "ram_shim_cmds.h"
#include "raster_cmds.h"
#include "Vraster_sim.h"
using ModType = Vraster_sim;
ModType *mod;

uint32_t main_time = 0;

double sc_time_stamp() {
	return main_time;
}

static void _assert(const char *file, int line, const char *exp, bool ev, const char *fmt, ...) {
	if (!ev) {
		va_list va;
		va_start(va, fmt);
		fprintf(stderr, "%s:%d: assertion failed: %s\n", file, line, exp);
		vfprintf(stderr, fmt, va);
		fprintf(stderr, "\n");
		va_end(va);
		exit(1);
	}
}

#define STRINGIFY(s) #s
/* ,##__VA_ARGS__ is a GNU C extension */
#define my_assert(e, fmt, ...) _assert(__FILE__, __LINE__, STRINGIFY(e), (e), fmt ,##__VA_ARGS__)

static void run_clock() {
#ifdef BAILOUT
	static int iters = 0;
#endif
	for (int i = 0; i < 2; i++) {
		mod->clk = !mod->clk;
		mod->eval();
		main_time++;
#ifdef BAILOUT
		iters++;
#endif
	}

#ifdef BAILOUT
	if (iters >= 1000000)
		exit(2);
#endif
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

using V = uint32_t;

// Verilator makes all ports unsigned, even when marked as signed in
// Verilog.
V sign_extend(V x, unsigned len, bool is_signed) {
	if (!is_signed)
		return x;
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

static int32_t read_raster_reg(int reg, unsigned siz, bool is_signed) {
	mod->kernel_cmd = reg;
	mod->kernel_ready = 1;
	while (!mod->kernel_finished)
		run_clock();
	mod->kernel_ready = 0;
	run_clock();

	return sign_extend(mod->kernel_data_out, siz, is_signed);
}

static int32_t write_raster_reg(int reg, unsigned siz, int32_t val, bool is_signed) {
	int32_t oldval = read_raster_reg(reg, siz, is_signed);

	mod->kernel_cmd = reg | RASTER_WRITE_BIT;
	mod->kernel_data_in = val;

	mod->kernel_ready = 1;
	while (!mod->kernel_finished)
		run_clock();
	mod->kernel_ready = 0;
	run_clock();

	int32_t cval = read_raster_reg(reg, siz, is_signed);
	my_assert(cval == val, "written value (%x) != read val (%x)\n", val, cval);

	return oldval;
}

static void write_shim_cmd(unsigned cmd, uint32_t val) {
	mod->shim_cmd = cmd;
	mod->shim_cmd_data = val;
	mod->shim_cmd_active = 1;

	while (!mod->shim_cmd_finished)
		run_clock();
	mod->shim_cmd_active = 0;
	run_clock();
}

static void read_shim_ptr() {
	mod->shim_cmd = RAM_SHIM_READ_PTR;
	mod->shim_cmd_active = 1;

	while (!mod->shim_cmd_finished)
		run_clock();
	mod->shim_cmd_active = 0;
	run_clock();
}

#define SAMPLES_PER_LINE 16
#define NUM_OF_LINES 16
static size_t expected_store_index = 0;

static void init_values() {
	for (int i = 0; i < ADCNUM; i++)
		mod->adc_data[i] = 0;
	mod->adc_finished = 0;

	mod->ram_valid = 0;

	my_assert(write_raster_reg(RASTER_MAX_SAMPLES, SAMPLEWID, SAMPLES_PER_LINE, false) == 0, "samples per line was not zero");
	my_assert(write_raster_reg(RASTER_MAX_LINES, SAMPLEWID, NUM_OF_LINES, false) == 0, "max lines was not zero");
	my_assert(write_raster_reg(RASTER_SETTLE_TIME, TIMERWID, 30, false) == 0, "settle time was not zero");
	my_assert(write_raster_reg(RASTER_DX, DAC_DATA_WID, 12, true) == 0, "dx was not zero");
	my_assert(write_raster_reg(RASTER_DY, DAC_DATA_WID, 12, true) == 0, "dy was not zero");
	my_assert(write_raster_reg(RASTER_USED_ADCS, ADCNUM, 0b111101011, false) == 0, "adcnum was not zero");
	expected_store_index = SAMPLES_PER_LINE * NUM_OF_LINES * 7 * 2;

	write_shim_cmd(RAM_SHIM_WRITE_LOC, 0x10000);
	write_shim_cmd(RAM_SHIM_WRITE_LEN, 0x0FFFF);
}

// Forward and reverse, so multiply by 2
static std::array<int32_t, SAMPLES_PER_LINE * NUM_OF_LINES * ADCNUM*2> stored_values;
static size_t store_index = 0;
static std::array<uint16_t, SAMPLES_PER_LINE * NUM_OF_LINES * ADCNUM*2*2> received_values;
static size_t pushed_index = 0;

static void handle_ram() {
	if (mod->ram_write && !mod->ram_valid) {
		my_assert(pushed_index < received_values.max_size(), "pushed_index (%zu) maxed out", pushed_index);
		received_values[pushed_index++] = mod->word;
		mod->ram_valid = 1;
	} else if (!mod->ram_write) {
		mod->ram_valid = 0;
	}
}

static void handle_adc() {
	uint32_t tmp_adc_arm = mod->adc_arm;
	int i = 0;
	static int amount_called = 0;

	if (mod->adc_arm && mod->adc_arm != mod->adc_finished) {
		while (tmp_adc_arm) {
			if (tmp_adc_arm & 1) {
				my_assert(store_index < stored_values.max_size(),
				          "%d = %zu", store_index, stored_values.max_size());
				uint32_t x = sign_extend(rand(), 24, false);
				memcpy(&stored_values[store_index], &x, sizeof(x));
				mod->adc_data[i] = stored_values[store_index];
				store_index++;
			}

			i++;
			tmp_adc_arm >>= 1;
		}
		mod->adc_finished = mod->adc_arm;
		fprintf(stderr, "amount called: %d\n", ++amount_called);
	} else if (!mod->adc_arm) {
		mod->adc_finished = 0;
	}
}

int main(int argc, char **argv) {
	init(argc, argv);
	init_values();
	run_clock();

	write_raster_reg(RASTER_ARM, 1, 1, false);

	while (mod->is_running) {
		run_clock();
		handle_ram();
		handle_adc();
	}

	my_assert(pushed_index % 2 == 0, "uneven pushed index %d", pushed_index);
	my_assert(store_index != pushed_index/2, "store_index (%d) != pushed_index/2(%d)\n", store_index, pushed_index/2);
	my_assert(store_index == expected_store_index, "store_index (%zu) != (%zu)", store_index, expected_store_index);
	exit(0);

	for (size_t i = 0; i < pushed_index; i += 2) {
		int32_t calcval = received_values[i+1] << 16 | received_values[i];
		my_assert(calcval == stored_values[i/2], "calcval = %x, stored_values = %x", calcval, stored_values[i/2]);
	}

	return 0;
}
