#include <vector>
#include <random>
#include <stdexcept>
#include <iostream>
#include <cstdlib>
#include "Vpd_pipeline.h"
#include "../testbench.hpp"


class PDPipelineTestbench : public TB<Vpd_pipeline> {
	public:
		void start_test(int, int, int, int, int);
		void check_data();
		PDPipelineTestbench(int _bailout = 0) : TB<Vpd_pipeline>(_bailout) {}
	private:
		void posedge() override;
};

void PDPipelineTestbench::posedge() {
}

void PDPipelineTestbench::check_data() {
}

void PDPipelineTestbench::start_test(int i_kp, int i_ki, int i_setpoint, int i_actual, int i_integral) {
	mod.i_kp = i_kp;
	mod.i_ki = i_ki;
	mod.i_setpoint = i_setpoint;
	mod.i_actual = i_actual;
	mod.i_integral = i_integral;
	run_clock();
}

PDPipelineTestbench *tb;

void cleanup() {
	delete tb;
}

#define NUM_INCRS 1000
int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);

	tb = new PDPipelineTestbench();
	atexit(cleanup);

	std::cout << "Checking pipeline math with random inputs" << std::endl;
	auto engine = std::default_random_engine{};
	auto adc_dist = std::uniform_int_distribution<int32_t>(0,(1 << 18) - 1);
	auto pd_dist = std::uniform_int_distribution<uint32_t>(0,(1 << 14) - 1);

	for (int i = 1; i < NUM_INCRS; i++) {
		int32_t i_kp = pd_dist(engine);
		uint32_t i_ki = pd_dist(engine);
		int32_t i_setpoint = adc_dist(engine);
		int32_t i_actual = adc_dist(engine);
		int32_t i_integral = adc_dist(engine);

		tb->start_test(i_kp, i_ki, i_setpoint, i_actual, i_integral);

		// Let the pipeline run through all 4 stages
		while (int j = 0; j<4; j++) {
			tb->run_clock();
		}

		// TODO: Dump input parameters, check 
		int32_t expected_error = i_actual - i_setpoint;
		if (tb->mod.o_integral != i_integral + expected_error) {
			throw std::logic_error("Output integral calculation did not have the expected value.");
		}
	}

	return 0;
}
