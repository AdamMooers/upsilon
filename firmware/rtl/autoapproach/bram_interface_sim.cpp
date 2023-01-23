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

#include "Vbram_interface.h"

using ModType = Vbram_interface;
using V = uint32_t;
ModType *mod;

constexpr uint32_t start_addr = 0x12340;

// #define BAILOUT_NUMBER 100000
#include "../boilerplate.cpp"

std::array<uint32_t, WORD_AMNT> ram_refresh_data;

static void handle_ram() {
	static int timer = 0;
	constexpr auto TIMER_MAX = 10;
	bool flip_flop = false;

	if (mod->ram_read) {
		timer++;
		if (timer == TIMER_MAX) {
			mod->ram_valid = 1;
			if (mod->ram_dma_addr < start_addr ||
			    mod->ram_dma_addr >= start_addr + WORD_AMNT*4) {
				printf("bad address %x\n", mod->ram_dma_addr);
				exit(1);
			}
			my_assert(mod->ram_dma_addr >= start_addr, "left oob access %x", mod->ram_dma_addr);
			my_assert(mod->ram_dma_addr < start_addr + WORD_AMNT*4, "right oob access %x", mod->ram_dma_addr);
			my_assert(mod->ram_dma_addr % 2 == 0, "unaligned access %x", mod->ram_dma_addr);

			if (mod->ram_dma_addr % 4 == 0) {
				mod->ram_word = ram_refresh_data[(mod->ram_dma_addr - start_addr)/4]& 0xFFFF;
			} else {
				mod->ram_word = ram_refresh_data[(mod->ram_dma_addr - start_addr)/4] >> 16;
			}
		}
	} else {
		mod->ram_valid = 0;
		timer = 0;
	}
}

static void handle_read_aa(size_t &i) {
	if (mod->word_ok) {
		uint32_t val = sign_extend(mod->word, 20);
		mod->word_next = 0;

		my_assert(val == ram_refresh_data[i], "received value %x (%zu) != %x", i, val, ram_refresh_data[i]);
		i++;
	} else if (!mod->word_next) {
		mod->word_next = 1;
	}
}

/* Test reading the entire array twice. */
static void test_aa_read_1() {
	size_t ind = 0;

	mod->word_next = 1;
	run_clock();
	while (!mod->word_last || (mod->word_last && mod->word_next)) {
		handle_read_aa(ind);
		run_clock();
	}
	my_assert(ind == WORD_AMNT, "read value %zu != %d\n", ind, WORD_AMNT);

	mod->word_next = 1;
	run_clock();
	ind = 0;
	while (!mod->word_last || (mod->word_last && mod->word_next)) {
		handle_read_aa(ind);
		run_clock();
	}
	my_assert(ind == WORD_AMNT, "second read value %zu != %d\n", ind, WORD_AMNT);
}

static void test_aa_read_interrupted() {
	size_t ind = 0;

	mod->word_next = 1;
	run_clock();
	for (int i = 0; i < 100; i++) {
		handle_read_aa(ind);
		run_clock();
		my_assert(!mod->word_last, "too many reads");
	}
	mod->word_rst = 1;
	run_clock();
	mod->word_rst = 0;
	run_clock();

	test_aa_read_1();
}

static void refresh_data() {
	for (size_t i = 0; i < RAM_WID; i++) {
		ram_refresh_data[i] = mask_extend(rand(), 20);
	}

	mod->refresh_start = 1;
	mod->start_addr = start_addr;
	run_clock();

	while (!mod->refresh_finished) {
		handle_ram();
		run_clock();
	}

	mod->refresh_start = 0;
	run_clock();

}

int main(int argc, char **argv) {
	init(argc, argv);

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
