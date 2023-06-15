/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
#pragma once
#include <cstddef>

template<size_t WORD_AMNT, size_t TIMER_MAX>
class BRAM_DMA_Sim {
	uint32_t *ram;

	uint32_t start_addr;
	size_t word_amnt;
	size_t timer_max;

	int sim_timer;

	void execute_ram_access(uint32_t ram_dma_addr, uint32_t &ram_word,
	                        uint32_t &ram_valid);
	public:
	void generate_random_data();
	BRAM_DMA(uint32_t _start_addr = 0x12340,
	         size_t _word_amnt = 2048,
	         size_t _timer_max = 10);
	~BRAM_DMA();
	void posedge(uint32_t ram_dma_addr, uint32_t &ram_word,
                     uint32_t ram_read, uint32_t &ram_valid);

};
