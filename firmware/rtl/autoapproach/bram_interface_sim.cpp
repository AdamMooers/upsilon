#include <limits>
#include <cstdlib>
#include <random>
#include <unistd.h>
#include <verilated.h>

#include "Vbram_interface.h"
#include "../testbench.hpp"

TB<Vbram_interface> *tb;
constexpr uint32_t start_addr = 0x12340;
std::array<uint32_t, WORD_AMNT> ram_refresh_data;

static void handle_ram() {
	static int timer = 0;
	constexpr auto TIMER_MAX = 10;
	bool flip_flop = false;

	if (tb->mod.ram_read) {
		timer++;
		if (timer == TIMER_MAX) {
			tb->mod.ram_valid = 1;
			if (tb->mod.ram_dma_addr < start_addr ||
			    tb->mod.ram_dma_addr >= start_addr + WORD_AMNT*4) {
				printf("bad address %x\n", tb->mod.ram_dma_addr);
				exit(1);
			}
			my_assert(tb->mod.ram_dma_addr >= start_addr, "left oob access %x", tb->mod.ram_dma_addr);
			my_assert(tb->mod.ram_dma_addr < start_addr + WORD_AMNT*4, "right oob access %x", tb->mod.ram_dma_addr);
			my_assert(tb->mod.ram_dma_addr % 2 == 0, "unaligned access %x", tb->mod.ram_dma_addr);

			if (tb->mod.ram_dma_addr % 4 == 0) {
				tb->mod.ram_word = ram_refresh_data[(tb->mod.ram_dma_addr - start_addr)/4]& 0xFFFF;
			} else {
				tb->mod.ram_word = ram_refresh_data[(tb->mod.ram_dma_addr - start_addr)/4] >> 16;
			}
		}
	} else {
		tb->mod.ram_valid = 0;
		timer = 0;
	}
}

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
	for (size_t i = 0; i < RAM_WID; i++) {
		ram_refresh_data[i] = mask_extend(rand(), 20);
	}

	tb->mod.refresh_start = 1;
	tb->mod.start_addr = start_addr;
	tb->run_clock();

	while (!tb->mod.refresh_finished) {
		handle_ram();
		tb->run_clock();
	}

	tb->mod.refresh_start = 0;
	tb->run_clock();

}

int main(int argc, char *argv[]) {
	Verilated::traceEverOn(true);
	tb = new TB<Vbram_interface>(argc, argv);

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
