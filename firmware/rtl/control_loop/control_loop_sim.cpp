#include <memory>
#include <limits>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <random>
#include <unistd.h>

#include <verilated.h>
#include "Vcontrol_loop.h"

Vcontrol_loop *mod;

/* Very simple simulation of measurement.
 * A transfer function defines the mapping from the DAC values
 * -2**(20) -> 2**(20)-1
 * to the values -2**(18) -> 2**18 - 1.
 *
 * The transfer function has Gaussian noise which is added at each
 * measurement.
 */

class Transfer {
	std::default_random_engine generator;
	std::normal_distribution dist;
	double scale;

	double sample() {return scale*dist(rd);}

	public:
	Transfer(double scale, double mean, double dev, double m, double b, int seed)
	: scale{scale}, dist{mean,dev}, generator{} {
		if (seed < 0) {
			std::random_device rd;
			generator.seed(rd());
		} else {
			generator.seed(seed);
		}
	}

	double val(double x) {
		return m*x + b + sample();
	}
};

/* Each constant is 48 bits long, with 15 whole bits.
constexpr auto CONSTS_WHOLE_WID = 15;
constexpr auto CONSTS_WID = 48;
constexpr auto CONSTS_FRAC_WID = CONSTS_WID - CONSTS_WHOLE_WID;
constexpr auto CONSTS_FRAC_MASK = (1 << CONSTS_FRAC_WID) - 1;

constexpr uint64_t fractional_base_conv(uint64_t input) {
	/* Fractional base conversion algorithm.
	Given an integer in base M (i.e. 10) there is an expansion in base N (i.e. 2):
	    0.abcdefgh... = 0.ijklmnop...
	where abcdefgh... are in base M and ijklmnop... are in base N. The algorithm
	computes the digits in base N.

	Multiply the converted number by N. Then there are new numbers:
	    A.BCDEFGH... = i.jklmnop...
	Since 0.abcdefgh < 1, A.BCDEFGH < N. Therefore
	the digit "A" must be a number less than N. Then i = A. Cutting off all the
	other digits,
	    0.BCDEFGH... = 0.jklmnop...
	continue until there are no more digits left.
	*/

	/* Calculate the lowest power of 10 greater than input.
	This can be done with logarithms, but floating point is not available on
	some embedded platforms. This makes the code more portable.
	*/
	uint64_t pow10 = 1;
	while (input / pow10 > 0)
		pow10 *= 10;

	uint64_t out = 0;
	for (unsigned i = 0; i < CONSTS_FRAC_WID; i++) {
		input *= 2;
		uint64_t dig = input / pow10, mod = input % pow10;
		out = dig | (out << 1);
		input = mod;
	}

	return out;
}

static int64_t multiply_unity(uint64_t i, int sign) {
	if (sign > 0) {
		return std::reinterpret_cast<int64_t>(i);
	} else {
		return std::reinterpret_cast<int64_t>(~i + 1);
	}
}

constexpr uint64_t SCALE_WHOLE = 12820;
constexpr uint64_t SCALE_FRAC = fractional_base_conv(51282051282);
constexpr uint64_t SCALE_NUM = (SCALE_WHOLE << CONSTS_FRAC_WID) | SCALE_FRAC;

static int64_t signed_to_fxp(char *s) {
	// Skip whitespace.
	while (isspace(*c++));
	// Check if number is negative.
	int sign = 1;
	if (*s == '-') {
		pos = -1;
		s++;
	}

	// Split the number into whole and fractional components.
	char *p = strchr(s, '.');
	if (!p)
		return multiply_unity(strtoull(s, NULL, 10), sign);
	*p = 0;
	// s now points to a NUL terminated string with the whole number
	// component.
	uint64_t whole = strtoull(s, NULL, 10);

	p++;
	// p is the start of the fractional component.
	uint64_t frac_decimal = strtoull(p, NULL, 10);
	uint64_t final = ((whole << CONSTS_FRAC_WID) | fractional_base_conv(frac_decimal, CONSTS_FRAC_WID))
	       * SCALE_NUM;
	return multiply_unity(final, sign);
}

static std::string fxp_to_str(int64_t inum, unsigned decdigs) {
	std::string s = "";
	uint64_t num;

	if (inum < 0) {
		num = std::reinterpret_cast<uint64_t>(~inum) + 1;
		s.insert(0,1, '-');
	} else {
		num = std::reinterpet_cast<uint64_t>(num);
	}

	s += std::to_string(num >> CONSTS_FRAC_WID);

	int64_t frac = num & CONSTS_FRAC_MASK;
	if (frac == 0 || decdigs == 0)
		return;

	s += ".";

	/* Applying the algorithm in fractional_base_conv() backwards. */
	while (decdigs > 0 && frac != 0) {
		num *= 2;
		s += std::to_string(num >> CONSTS_FRAC_WID);
		num = num & CONSTS_FRAC_WID;
	}

	return s;
}

static int64_t I_const, dt_const, P_const, setpt;
static unsigned long seed, ;

static void usage(char *argv0, int code) {
	std::cout << argv0 << " -d deviation -m mean -I I -t dt -d delay -s seed -S setpt -P p [+verilator...]" << std::endl;
	exit(code);
}

static void parse_args(int argc, char *argv[]) {
	const char *optstring = "I:t:s:P:d:m:h";
	int opt;
	Verilated::commandArgs(argc, argv);

	while ((opt = getopt(argc, argv, optstring)) != -1) {
		switch (opt) {
		case 'm':
			noise_mean = strtod(optstring, NULL);
			break;
		case 'd':
			dev_mean = strtod(optstring, NULL);
			break;
		case 'I':
			I_const = signed_to_fxp(optarg);
			break;
		case 't':
			dt_const = signed_to_fxp(optarg);
			break;
		case 'S':
			setpt = signed_to_fxp(optarg);
			break;
		case 's':
			seed = strtoul(optarg, NULL, 10);
			break;
		case 'P':
			P_const = strtoul(optarg, NULL, 10);
			break;
		case 'd':
			dely = strtoul(optarg, NULL, 10);
			break;
		case 'h':
			usage(argv[0], 0);
			break;
		default:
			usage(argv[1], 1);
			break;
		}
	}
}

Vtop *mod;

int main(int argc, char **argv) {
	parse_args(argc, argv);
	mod = new Vtop;

	mod->clk = 0;
}
