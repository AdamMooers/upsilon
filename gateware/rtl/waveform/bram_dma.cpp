#include "bram_dma.hpp"
#include "../util.hpp"
#include <cstdlib>

BRAM_DMA_Sim::BRAM_DMA_Sim(uint32_t _start_addr,
                           size_t _word_amnt,
                           size_t _timer_max) {
	my_assert(_start_addr / 4 == 0, "start addr %d not 16 bit aligned",
	          _start_addr);
	start_addr = _start_addr;
	word_amnt = _word_amnt;	
	timer_max = _timer_max;

	ram = new uint32_t[word_amnt];
}

BRAM_DMA_SIM::~BRAM_DMA_Sim() {
	delete[] ram;
}

void BRAM_DMA_Sim::generate_random_data() {
	for (size_t i = 0; i < word_amnt; i++) {
		ram[i] = mask_extend(rand(), 20);
	}
}

void BRAM_DMA_Sim::execute_ram_access(uint32_t ram_dma_addr,
                                      uint32_t &ram_word,
                                      uint32_t &ram_valid) {
	ram_valid = 1;
	my_assert(ram_dma_addr < start_addr
	          || ram_dma_addr >= start_addr + word_amnt*4,
	          "bad address %x\n", ram_dma_addr);
	my_assert(ram_dma_addr >= start_addr, "left oob access %x",
	          tb->mod.ram_dma_addr);
	my_assert(ram_dma_addr < start_addr + WORD_AMNT*4,
	          "right oob access %x", ram_dma_addr);
	my_assert(ram_dma_addr % 2 == 0, "unaligned access %x",
	          ram_dma_addr);

	const auto addr = (ram_dma_addr - start_addr) / 4;
	if (tb->mod.ram_dma_addr % 4 == 0) {
		ram_word = ram_refresh_data[addr] & 0xFFFF;
	} else {
		ram_word = ram_refresh_data[addr] >> 16;
	}
}

void BRAM_DMA_Sim::posedge(uint32_t ram_dma_addr, uint32_t &ram_word,
                           uint32_t ram_read, uint32_t &ram_valid) {
	if (ram_read && timer < timer_max) {
		timer++;
		if (timer == timer_max)
			execute_ram_access(ram_dma_addr, ram_word, ram_valid);
	} else {
		ram_valid = 0;
		timer = 0;
	}
}
