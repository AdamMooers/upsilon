#include <stdint.h>
#include "../boot/pico0_mmio.h"

void _start(void)
{
	*PARAMS_ZPOS = *PARAMS_CL_I;

	for (;;) ;
}
