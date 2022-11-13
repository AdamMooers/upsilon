#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <vector>
#include <limits>
#include <random>

using V = int64_t;
constexpr V V_min = std::numeric_limits<V>::min();

class Transfer {
	std::default_random_engine generator;
	std::normal_distribution<> dist;
	double scale;
	double m;
	double b;

	double sample() {return scale*dist(generator);}

	public:
	Transfer(double scale, double mean, double dev, double m, double b, int seed)
	: scale{scale}, dist{mean,dev}, generator{}, m{m}, b{b} {
		if (seed < 0) {
			std::random_device rd;
			generator.seed(rd());
		} else {
			generator.seed(seed);
		}
	}

	int64_t val(double x) {
		return m*x + b + sample();
	}
};

V mulsat(V x, V y, unsigned siz, unsigned discard);

struct fixed_point {
	V val;
	unsigned whole_len;
	unsigned frac_len;
};

std::string fxp_to_string(const struct fixed_point &fxp);
// V asr(V x, unsigned len);
V sign_extend(V x, unsigned len);
