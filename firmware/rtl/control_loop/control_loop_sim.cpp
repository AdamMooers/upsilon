#include <memory>
#include <limits>
#include <cstdint>
#include <iostream>
#include <random>

#include <verilated.h>
#include "Vcontrol_loop.h"

Vcontrol_loop *mod;

/* Very simple simulation of measurement.
 * A transfer function defines the mapping from the DAC values
 * -2**(20) -> 2**(20)-1
 * to the values -2**(18) -> 2**18 - 1.
 *
 * The transfer function has Gaussian noise which is added at each
 * measurement.
 */

class Transfer {
	std::random_device rd;
	std::normal_distribution dist;
	double scale;

	double sample() {return scale*dist(rd);}

	public:
	Transfer(double scale, double mean, double dev, double m, double b)
	: scale{scale}, rd{}, dist{mean,dev} {}

	double val(double x) {
		return m*x + b + sample();
	}
};

int main(int argc, char **argv) {

}
