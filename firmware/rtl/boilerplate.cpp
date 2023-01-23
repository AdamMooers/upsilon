#include <cstdio>

uint32_t main_time = 0;

double sc_time_stamp() {
	return main_time;
}

static void _assert(const char *file, int line, const char *exp, bool ev, const char *fmt, ...) {
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

#ifdef BAILOUT_NUMBER
# define BAILOUT(...) __VA_ARGS__
#else
# define BAILOUT(...)
#endif

static void run_clock() {
	BAILOUT(static int bailout;)
	for (int i = 0; i < 2; i++) {
		mod->clk = !mod->clk;
		mod->eval();
		main_time++;
		BAILOUT(bailout++;)
	}
	BAILOUT(if (bailout >= BAILOUT_NUMBER) exit(1);)
}

#undef BAILOUT

static void cleanup_exit() {
	mod->final();
	delete mod;
}

static void init(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	mod = new ModType;
	mod->clk = 0;
	atexit(cleanup_exit);

	char *seed = getenv("RANDOM_SEED");
	if (seed) {
		unsigned long i = strtoul(seed, NULL, 10);
		srand((unsigned int)i);
	}
}

static V sign_extend(V x, unsigned len) {
	/* if high bit is 1 */
	if (x >> (len - 1) & 1) {
		V mask = (1 << len) - 1;
		return ~mask | x;
	} else {
		return x;
	}
}
#define MASK(x,v) ((x) & ((1 << (v)) - 1))

static V mask_extend(V x, unsigned len) {
	return sign_extend(MASK(x,len), len);
}
