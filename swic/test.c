#include <stdint.h>

void _start(void)
{
	volatile uint32_t *write = (volatile uint32_t *)(0x100000 + 0x10);
	volatile uint32_t *read = (volatile uint32_t *)( 0x100000 + 0x0);
	volatile uint32_t *next_read = (volatile uint32_t *)(0x100FF);
	*write = *read;
	*next_read = 0xdeadbeef;

	for (;;) ;
}
