#include <random>
#include <cmath>

#include "Vautoapproach_sim.h"
#include "../testbench.hpp"

/* TODO: generalize so bram_interface_sim can use it.
 * This should make a triangle wave.
 */
class RefreshModule {
	uint32_t *store_32;
	size_t word_amnt;
	bool pending_refresh_start;

	public:
	void posedge(uint8_t &refresh_start, uint32_t &start_addr,
	             uint8_t refresh_finished) {
		if (refresh_start && refresh_finished) {
			refresh_start = 0;
		} else if (pending_refresh_start && !refresh_start) {
			pending_refresh_start = false;
			refresh_start = 1;
		}
	}

	RefreshModule(size_t _word_amnt, size_t _start_addr)
	: word_amnt{_word_amnt}
	, start_addr{_start_addr} {
		store_32 = new uint32_t[_start_addr];
		for (size_t i = 0; i < start_addr; i++) {
			/* 0xFFFFF is the maximum DAC value */
			store_32[i] = 0xFFFFF*max(double)i/start_addr;
		}
		pending_refresh_start = true;
	}

	~RefreshModule() {
		delete[] store_32;
	}
};

/* TODO: make generic SPI delay class because this code has been duplicated
 * many times over now. This function is also similar to the control loop
 * ADC simulation. */
class GaussianZPiezo {
	std::default_random_engine generator;
	std::normal_distribution<> dist;
	double scale;
	double setpt;
	double midpt;
	double stretch;

	double sample() {return scale*dist(generator);}

	GaussianZPiezo(double scale, double mean, double dev, double setpt,
	               double midpt, double stretch, int seed,
	               uint16_t dac_wait_count,
	               uint16_t adc_wait_count)
	: scale{scale}, dist{mean,dev}, generator{},
	, setpt{setpt}, midpt{midpt}, stretch{stretch},
	, dac_wait_count_max{dac_wait_count}
	, adc_wait_count_max{adc_wait_count} {
		if (seed < 0) {
			std::random_device rd;
			generator.seed(rd());
		} else {
			generator.seed(seed);
		}
	}
	/* Sigmoid function. This function is

	                c(x-d)
	f(x) = A*-------------------
	          sqrt(1+(c(x-d))^2)

	where A is the setpoint and c is how compressed the sigmoid is.
	*/

	double f(uint32_t x) {
		double x_shift = x - midpt + sample();
		return setpt*stretch*x_shift/sqrt(fma(x_shift,x_shift,1));
	}

	public:

	void posedge(uint8_t &dac_finished, uint8_t dac_arm,
	             uint32_t dac_out,
	             uint8_t &adc_finished, uint8_t adc_arm,
	             uint32_t &adc_out) {
		if (adc_arm && adc_wait_counter == adc_wait_counter_max &&
		    !adc_finished) {
			adc_finished = 1;
			adc_out = sample();
		} else if (!adc_arm) {
			adc_finished = 0;
			adc_wait_counter = 0;
		} else {
			adc_wait_counter++;
		}

		if (dac_arm && dac_wait_counter == dac_wait_counter_max &&
		    !dac_finished) {
			dac_finished = 1;
	}
};

class AA_TB : TB<Vautoapproach_sim> {
	RefreshModule refresh;
	GaussianZPiezo piezo;

	void posedge() override;
	AA_TB(size_t word_amnt, uint32_t start_addr)
	: refresh{word_amnt, start_addr} {}

	~AA_TB() {}
};

AA_TB::posedge() {
	refresh.posedge(mod.refresh_start, mod.start_addr,
	                mod.refresh_finished);
}

int main(int argc, char **argv) {
	return 0;
}
