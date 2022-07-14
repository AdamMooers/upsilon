#pragma once

int32_t adc_read(size_t num, unsigned wid);

uint32_t dac_write_raw(size_t n, uint32_t data);
void dac_write_v(size_t n, uint32_t v);
int dac_init(size_t n);
