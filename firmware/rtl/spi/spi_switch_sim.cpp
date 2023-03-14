#include "../util.hpp"
#include "Vspi_switch.h"
Vspi_switch *tb;

static void set_and_check(unsigned int selected, unsigned int num, unsigned int expected) {
	tb->miso = 1;
	tb->mosi_ports = 1 << num;
	tb->sck_ports = 1 << num;
	tb->ss_L_ports = 1 << num;
	tb->eval();

	my_assert(tb->mosi == expected, "%u != %u", tb->mosi, expected);
	my_assert(tb->sck == expected, "%u != %u", tb->sck, expected);
	my_assert(tb->ss_L == expected, "%u != %u", tb->ss_L, expected);
	my_assert(tb->miso_ports == 1 << selected, "%u != %u", tb->miso_ports, 1 << selected);
}

int main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	tb = new Vspi_switch();

	printf("Default behavior.\n");
	tb->select = 0;
	set_and_check(0, 0, 1);
	set_and_check(0, 1, 0);
	set_and_check(0, 2, 0);

	printf("Selecting the first port.\n");
	tb->select = 1;
	set_and_check(0, 0, 1);
	set_and_check(0, 1, 0);
	set_and_check(0, 2, 0);

	printf("Selecting the second port.\n");
	tb->select = 1 << 1;
	set_and_check(1, 0, 0);
	set_and_check(1, 1, 1);
	set_and_check(1, 2, 0);

	printf("Selecting the third port.\n");
	tb->select = 1 << 2;
	set_and_check(2, 0, 0);
	set_and_check(2, 1, 0);
	set_and_check(2, 2, 1);

	tb->final();
	delete tb;

	return 0;
}
