#pragma once
#include <cstdint>
#include <verilated.h>

/* https://zipcpu.com/blog/2017/06/21/looking-at-verilator.html */
template <class TOP> class TB {
	int tick_count;
	int bailout;

	public:
	TOP mod;
	VerilatedContext vc;

	TB(int argc, char *argv[], int _bailout = 0) : mod(), bailout(_bailout), vc() {
		vc.commandArgs(argc, argv);
		vc.traceEverOn(true);
		mod.clk = 0;
		tick_count = 0;
	}

	virtual ~TB() {
		mod.final();
	}

	virtual void run_clock() {
		mod.clk = !mod.clk;
		mod.eval();
		vc.timeInc(1);
		mod.clk = !mod.clk;
		mod.eval();
		vc.timeInc(1);
		tick_count++;

		if (bailout > 0 && tick_count >= bailout)
			exit(1);
	}
};

static inline void _assert(const char *file, int line, const char *exp, bool ev, const char *fmt, ...) {
	if (!ev) {
		va_list va;
		va_start(va, fmt);
		fprintf(stderr, "%s:%d: assertion failed: %s\n", file, line, exp);
		vfprintf(stderr, fmt, va);
		fprintf(stderr, "\n");
		va_end(va);
		exit(1);
	}
}
#define STRINGIFY(s) #s
/* ,##__VA_ARGS__ is a GNU C extension */
#define my_assert(e, fmt, ...) _assert(__FILE__, __LINE__, STRINGIFY(e), (e), fmt ,##__VA_ARGS__)

template<typename V>
static inline V sign_extend(V x, unsigned len) {
	/* if high bit is 1 */
	if (x >> (len - 1) & 1) {
		V mask = (1 << len) - 1;
		return ~mask | x;
	} else {
		return x;
	}
}

#define MASK(x,v) ((x) & ((1 << (v)) - 1))
template<typename V>
static inline V mask_extend(V x, unsigned len) {
	return sign_extend<V>(MASK(x,len), len);
}
