#include "control_loop_math_implementation.h"

#define BITMASK(n) (((V)1 << (n)) - 1)

/* only works on 64 bit GCC/Clang, can use boost (eww boost) */

static V sat(__int128_t r, unsigned siz, unsigned discard) {
	r >>= discard;
	/* Since this is signed numbers, the actual number of bits of
	 * the largest number is one less than the bit size. */
	siz -= 1;

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

V mulsat(V x, V y, unsigned siz, unsigned discard) {
	__int128_t v = (__int128_t)x * (__int128_t)y;

	return sat(v, siz, discard);
}

static int d2c(unsigned d) {
	switch (d) {
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

#if 0
V asr (V x, unsigned len) {
	if (x >= 0)
		return x >> len;
	x >>= len;

	/* x is shifted-right by N bits. This makes a mask of
	 * N bits, and shifts it to the highest position.
	 */
	V mask = ((1 << len) - 1) << (sizeof(x) * CHAR_BITS - len);
	return mask | x;
}
#endif

V sign_extend(V x, unsigned len) {
	/* if high bit is 1 */
	if (x >> (len - 1) & 1) {
		V mask = (1 << len) - 1;
		return ~mask | x;
	} else {
		return x;
	}
}
