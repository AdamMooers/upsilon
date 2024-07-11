#include <random>
#include <stdexcept>
#include <iostream>
#include <cstdlib>
#include <string>
#include "Vpd_pipeline.h"
#include "../testbench.hpp"


class PDPipelineTestbench : public TB<Vpd_pipeline> {
	public:
		void start_test(int, int, int, int, int);
		void dump_inputs();
		void dump_outputs();
		PDPipelineTestbench(int _bailout = 0) : TB<Vpd_pipeline>(_bailout) {}
	private:
		void posedge() override;
};

void PDPipelineTestbench::posedge() {
}

void PDPipelineTestbench::start_test(
	int32_t i_kp, 
	int32_t i_ki, 
	int32_t i_setpoint, 
	int32_t i_actual, 
	int32_t i_integral) {
	mod.i_kp = i_kp;
	mod.i_ki = i_ki;
	mod.i_setpoint = i_setpoint;
	mod.i_actual = i_actual;
	mod.i_integral = i_integral;
	run_clock();
}

void PDPipelineTestbench::dump_outputs() {
	std::cout 
	<< "o_integral: " << static_cast<int32_t>(mod.o_integral) << std::endl
	<< "o_pd: " << static_cast<int32_t>(mod.o_pd) << std::endl;
}

void PDPipelineTestbench::dump_inputs() {
	std::cout 
	<< "i_kp: " <<  static_cast<int32_t>(mod.i_kp) << std::endl
	<< "i_ki: " << static_cast<int32_t>(mod.i_ki) << std::endl
	<< "i_setpoint: " << static_cast<int32_t>(mod.i_setpoint) << std::endl
	<< "i_actual: " << static_cast<int32_t>(mod.i_actual) << std::endl
	<< "i_integral: " << static_cast<int32_t>(mod.i_integral) << std::endl;
}

PDPipelineTestbench *tb;

void cleanup() {
	delete tb;
}


#define NUM_INCRS 10000
int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);

	tb = new PDPipelineTestbench();
	atexit(cleanup);

	std::cout << "Checking pipeline math with " << NUM_INCRS << " random inputs" << std::endl;
	auto engine = std::default_random_engine{};

	auto adc_dist = std::uniform_int_distribution<int32_t>(-(1 << 17),(1 << 17) - 1);
	auto pd_dist = std::uniform_int_distribution<int32_t>(-(1 << 14),(1 << 14) - 1);

	for (int i = 1; i < NUM_INCRS; i++) {
		uint32_t i_kp = pd_dist(engine);
		uint32_t i_ki = pd_dist(engine);
		int32_t i_setpoint = adc_dist(engine);
		int32_t i_actual = adc_dist(engine);
		int32_t i_integral = adc_dist(engine);

		tb->start_test(i_kp, i_ki, i_setpoint, i_actual, i_integral);

		// Let the pipeline run through all 4 stages
		for (int j = 0; j<4; j++) {
			tb->run_clock();
		}

		int32_t expected_error = i_actual - i_setpoint;
		int32_t expected_o_integral = i_integral + expected_error;
		int32_t expected_o_pd =  i_kp*expected_error + i_ki*expected_o_integral;

		if (static_cast<int32_t>(tb->mod.o_integral) != expected_o_integral) {
			tb->dump_inputs();
			tb->dump_outputs();
			throw std::logic_error(
				"Output integral calculation did yield the expected value. (expected mod.o_integral = "+
				std::to_string(expected_o_integral)+")");
		}

		if (static_cast<int32_t>(tb->mod.o_pd) != expected_o_pd) {
			tb->dump_inputs();
			tb->dump_outputs();
			throw std::logic_error(
				"PD calculation did not yield the expected value. (expected mod.o_pd = "+
				std::to_string(expected_o_pd)+")");
		}
	}

	return 0;
}
