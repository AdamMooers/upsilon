#include <random>
#include <stdexcept>
#include <iostream>
#include <cstdlib>
#include <string>
#include "Vpd_pipeline.h"
#include "../testbench.hpp"


class PDPipelineTestbench : public TB<Vpd_pipeline> {
	public:
		void start_test(int32_t, int32_t, int32_t, int32_t, int32_t);
		void dump_inputs();
		void dump_outputs();
		PDPipelineTestbench(int _bailout = 0) : TB<Vpd_pipeline>(_bailout) {}
	private:
		void posedge() override;
};

void PDPipelineTestbench::posedge() {
}

void PDPipelineTestbench::start_test(
	int32_t kp, 
	int32_t ki, 
	int32_t setpoint, 
	int32_t actual, 
	int32_t integral_input) {
	mod.kp = kp;
	mod.ki = ki;
	mod.setpoint = setpoint;
	mod.actual = actual;
	mod.integral_input = integral_input;
	run_clock();
}

void PDPipelineTestbench::dump_outputs() {
	std::cout 
	<< "integral_result: " << static_cast<int32_t>(mod.integral_result) << std::endl
	<< "pd_result: " << static_cast<int32_t>(mod.pd_result) << std::endl;
}

void PDPipelineTestbench::dump_inputs() {
	std::cout 
	<< "kp: " <<  static_cast<int32_t>(mod.kp) << std::endl
	<< "ki: " << static_cast<int32_t>(mod.ki) << std::endl
	<< "setpoint: " << static_cast<int32_t>(mod.setpoint) << std::endl
	<< "actual: " << static_cast<int32_t>(mod.actual) << std::endl
	<< "integral_input: " << static_cast<int32_t>(mod.integral_input) << std::endl;
}

PDPipelineTestbench *tb;

void cleanup() {
	delete tb;
}

#define NUM_INCRS 100000
int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);

	tb = new PDPipelineTestbench();
	atexit(cleanup);

	std::cout << "Checking pipeline math with " << NUM_INCRS << " random inputs" << std::endl;
	auto engine = std::default_random_engine{};

	auto adc_dist = std::uniform_int_distribution<int32_t>(-(1 << 17),(1 << 17) - 1);

	// We limit these to 14 bits to ensure we don't overflow pd_result
	auto pd_dist = std::uniform_int_distribution<int32_t>(-(1 << 14),(1 << 14) - 1);

	for (int i = 1; i < NUM_INCRS; i++) {
		uint32_t kp = pd_dist(engine);
		uint32_t ki = pd_dist(engine);
		int32_t setpoint = adc_dist(engine);
		int32_t actual = adc_dist(engine);
		int32_t integral_input = adc_dist(engine);

		tb->start_test(kp, ki, setpoint, actual, integral_input);

		// Let the pipeline run through all 4 stages
		for (int j = 0; j<4; j++) {
			tb->run_clock();
		}

		int32_t expected_error = actual - setpoint;
		int32_t expected_integral_result = integral_input + expected_error;
		int32_t expected_pd_result =  kp*expected_error + ki*expected_integral_result;

		if (static_cast<int32_t>(tb->mod.integral_result) != expected_integral_result) {
			tb->dump_inputs();
			tb->dump_outputs();
			throw std::logic_error(
				"Output integral calculation did yield the expected value. (expected mod.integral_result = "+
				std::to_string(expected_integral_result)+")");
		}

		if (static_cast<int32_t>(tb->mod.pd_result) != expected_pd_result) {
			tb->dump_inputs();
			tb->dump_outputs();
			throw std::logic_error(
				"PD calculation did not yield the expected value. (expected mod.pd_result = "+
				std::to_string(expected_pd_result)+")");
		}
	}

	return 0;
}
