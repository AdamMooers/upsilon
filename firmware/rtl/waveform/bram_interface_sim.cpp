#include <limits>
#include <cstdlib>
#include <random>
#include <unistd.h>
#include <verilated.h>

#include "Vbram_interface_sim.h"
#include "../testbench.hpp"

std::array<uint32_t, WORD_AMNT> ram_refresh_data;
TB<Vbram_interface_sim> *tb;

static void handle_read_aa(size_t &i) {
	if (tb->mod.word_ok) {
		uint32_t val = sign_extend(tb->mod.word, 20);
		tb->mod.word_next = 0;

		my_assert(val == ram_refresh_data[i], "received value %x (%zu) != %x", i, val, ram_refresh_data[i]);
		i++;
	} else if (!tb->mod.word_next) {
		tb->mod.word_next = 1;
	}
}

/* Test reading the entire array twice. */
static void test_aa_read_1() {
	size_t ind = 0;

	tb->mod.word_next = 1;
	tb->run_clock();
	while (!tb->mod.word_last || (tb->mod.word_last && tb->mod.word_next)) {
		handle_read_aa(ind);
		tb->run_clock();
	}
	my_assert(ind == WORD_AMNT, "read value %zu != %d\n", ind, WORD_AMNT);

	tb->mod.word_next = 1;
	tb->run_clock();
	ind = 0;
	while (!tb->mod.word_last || (tb->mod.word_last && tb->mod.word_next)) {
		handle_read_aa(ind);
		tb->run_clock();
	}
	my_assert(ind == WORD_AMNT, "second read value %zu != %d\n", ind, WORD_AMNT);
}

static void test_aa_read_interrupted() {
	size_t ind = 0;

	tb->mod.word_next = 1;
	tb->run_clock();
	for (int i = 0; i < 100; i++) {
		handle_read_aa(ind);
		tb->run_clock();
		my_assert(!tb->mod.word_last, "too many reads");
	}
	tb->mod.word_rst = 1;
	tb->run_clock();
	tb->mod.word_rst = 0;
	tb->run_clock();

	test_aa_read_1();
}

static void refresh_data() {
	for (size_t i = 0; i < WORD_AMNT; i++) {
		uint32_t val = mask_extend(rand(), 20);
		ram_refresh_data[i] = val;
		tb->mod.backing_store[i*2] = val & 0xFFFF;
		tb->mod.backing_store[i*2+1] = val >> 16;
	}

	tb->mod.refresh_start = 1;
	tb->mod.start_addr = 0x12340;
	tb->run_clock();

	while (!tb->mod.refresh_finished)
		tb->run_clock();

	tb->mod.refresh_start = 0;
	tb->run_clock();

}

int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	Verilated::fatalOnError(false);

	tb = new TB<Vbram_interface_sim>();

	printf("test basic read/write\n");
	refresh_data();
	test_aa_read_1();
	refresh_data();
	test_aa_read_1();

	printf("test resetting\n");
	test_aa_read_interrupted();

	printf("ok\n");

	return 0;
}
