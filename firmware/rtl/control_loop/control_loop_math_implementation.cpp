#include "control_loop_math_implementation.h"

#define BITMASK(n) (((V)1 << (n)) - 1)

static V sat(V r, unsigned siz) {
	if (r >= BITMASK(siz)) {
		return BITMASK(siz);
	} else if (r <= -BITMASK(siz)) {
		V allzero = ~((V) 0);
		// make (siz - 1) zero bits
		return allzero & (allzero << (siz - 1));
	} else {
		return r; 
	}
}


V calculate_dt(V cycles, unsigned siz) {
	constexpr V sec_per_cycle = 0b10101011110011;

	return sat(sec_per_cycle * cycles, siz);
}

static char d2c(int c) {
	switch (c % 10) {
	case 0: return '0';
	case 1: return '1';
	case 2: return '2';
	case 3: return '3';
	case 4: return '4';
	case 5: return '5';
	case 6: return '6';
	case 7: return '7';
	case 8: return '8';
	case 9: return '9';
	default: return '?';
	}
}

std::string fxp_to_string(const struct fixed_point &fxp) {
	std::string r = std::to_string((fxp.val >> fxp.frac_len) & BITMASK(fxp.whole_len));
	V frac = fxp.val & BITMASK(fxp.frac_len);

	r.push_back('.');

	for (unsigned i = 0; i < fxp.frac_len; i++) {
		frac *= 10;
		r.push_back(d2c(frac >> fxp.frac_len));
		frac &= BITMASK(fxp.frac_len);
	}

	return r;
}
