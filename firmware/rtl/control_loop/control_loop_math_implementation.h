#pragma once
#include <cstdint>
#include <string>
#include <utility>
#include <limits>

using V = int64_t;
constexpr V V_min = std::numeric_limits<V>::min();

struct fixed_point {
	V val;
	unsigned whole_len;
	unsigned frac_len;
};

V calculate_dt(V cycles, unsigned siz);
std::string fxp_to_string(const struct fixed_point &fxp);
