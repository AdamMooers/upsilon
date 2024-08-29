/* Copyright 2024 (C) Adam Mooers
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
#include <random>
#include <stdexcept>
#include <iostream>
#include <cstdlib>
#include <string>
#include "Vpi_pipeline.h"
#include "Vpi_pipeline_pi_pipeline.h"
#include "../testbench.hpp"


class PIPipelineTestbench : public TB<Vpi_pipeline> {
	public:
		void run_test(int32_t, int32_t, int32_t, int32_t, int32_t);
		void dump_inputs();
		void dump_outputs();
		void flush_pipeline_and_test_result_valid();
		PIPipelineTestbench(int _bailout = 0) : TB<Vpi_pipeline>(_bailout) {}
	private:
		void posedge() override;
};

void PIPipelineTestbench::posedge() {
}

void PIPipelineTestbench::flush_pipeline_and_test_result_valid() {
	// Generate a positive edge
	mod.start = 0;
	this->run_clock();
	mod.start = 1;

	int pipeline_cycle_count;

	for (pipeline_cycle_count = 1; pipeline_cycle_count<=5-1; pipeline_cycle_count++) {
		this->run_clock();
		if (static_cast<int32_t>(mod.result_valid) != 0) {
			throw std::logic_error("Expected result_valid to be 0 in the "
			+std::to_string(pipeline_cycle_count)+"th clock cycle.");
		}
	}

	this->run_clock();
	if (static_cast<int32_t>(mod.result_valid) == 0) {
		throw std::logic_error("Expected result_valid to be 1 in the "
		+std::to_string(pipeline_cycle_count)+"th clock cycle.");
	}
}

void PIPipelineTestbench::run_test(
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

	uint32_t OUTPUT_RANGE_BITS = mod.pi_pipeline->OUTPUT_RANGE_BITS;

	flush_pipeline_and_test_result_valid();

	int32_t expected_error = actual - setpoint;
	int32_t expected_integral_result = integral_input + expected_error;
	int64_t expected_unsaturated_pi_result = 
		kp*static_cast<int64_t>(expected_error) + 
		ki*static_cast<int64_t>(expected_integral_result);
	int32_t expected_pi_result = static_cast<int32_t>(expected_unsaturated_pi_result);

	if (static_cast<int32_t>(mod.integral_result) != expected_integral_result) {
		this->dump_inputs();
		this->dump_outputs();
		throw std::logic_error(
			"Output integral calculation did yield the expected value. (expected mod.integral_result = "+
			std::to_string(expected_integral_result)+")");
	}

	if (expected_unsaturated_pi_result < -(static_cast<int64_t>(1) << (OUTPUT_RANGE_BITS-1))) {
		if (mod.pi_result_underflow_detected != 1) {
			this->dump_inputs();
			this->dump_outputs();
			std::cout << "expected_unsaturated_pi_result = " << expected_unsaturated_pi_result << std::endl;
			throw std::logic_error("Result underflowed but underflow flag was not set.");

		}
	} else if (expected_unsaturated_pi_result > (static_cast<int64_t>(1) << (OUTPUT_RANGE_BITS-1))-1) {
		if (mod.pi_result_overflow_detected != 1) {
			this->dump_inputs();
			this->dump_outputs();
			std::cout << "expected_unsaturated_pi_result = " << expected_unsaturated_pi_result << std::endl;
			throw std::logic_error("Result overflowed but overflow flag was not set.");
		}
	} else if (static_cast<int32_t>(mod.pi_result) != expected_pi_result) {
		this->dump_inputs();
		this->dump_outputs();
		throw std::logic_error(
			"PI calculation did not yield the expected value. (expected mod.pi_result = "+
			std::to_string(expected_pi_result)+")");
	}
}

void PIPipelineTestbench::dump_outputs() {
	std::cout 
	<< "integral_result: " << static_cast<int32_t>(mod.integral_result) << std::endl
	<< "pi_result: " << static_cast<int32_t>(mod.pi_result) << std::endl
	<< "pi_result_overflow_detected: " << static_cast<uint32_t>(mod.pi_result_overflow_detected) << std::endl
	<< "pi_result_underflow_detected: " << static_cast<uint32_t>(mod.pi_result_underflow_detected) << std::endl;
}

void PIPipelineTestbench::dump_inputs() {
	std::cout 
	<< "kp: " <<  static_cast<int32_t>(mod.kp) << std::endl
	<< "ki: " << static_cast<int32_t>(mod.ki) << std::endl
	<< "setpoint: " << static_cast<int32_t>(mod.setpoint) << std::endl
	<< "actual: " << static_cast<int32_t>(mod.actual) << std::endl
	<< "integral_input: " << static_cast<int32_t>(mod.integral_input) << std::endl;
}

PIPipelineTestbench *tb;

void cleanup() {
	delete tb;
}

#define NUM_INCRS 100000000
int main(int argc, char *argv[]) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);

	tb = new PIPipelineTestbench();
	atexit(cleanup);

	std::cout << "Checking pipeline math with " << NUM_INCRS << " random inputs" << std::endl;
	auto engine = std::default_random_engine{};

	auto adc_dist = std::uniform_int_distribution<int32_t>(-(1 << 17),(1 << 17) - 1);

	// This value will be clamped by the SWIC to the provided range
	auto int_dist = std::uniform_int_distribution<int32_t>(-(1 << 19),(1 << 19) - 1);

	// These are set to scale across the entire range of the DAC output
	auto pi_dist = std::uniform_int_distribution<int32_t>(-(1 << 19),(1 << 19) - 1);

	for (int i = 1; i < NUM_INCRS; i++) {
		uint32_t kp = pi_dist(engine);
		uint32_t ki = pi_dist(engine);
		int32_t setpoint = adc_dist(engine);
		int32_t actual = adc_dist(engine);
		int32_t integral_input = adc_dist(engine);

		tb->run_test(kp, ki, setpoint, actual, integral_input);
	}

	return 0;
}
