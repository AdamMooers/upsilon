/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
//testbench for intsat module
//Timothy Burman, 2022

module intsat_testbench
#(

	parameter IN_LEN = 64,
	parameter LTRUNC = 32

	
)
(
	//Outputs
	output signed [IN_LEN-LTRUNC-1:0] outp
);



reg signed [IN_LEN-1:0] inp;

intsat testbench (inp, outp);

initial
begin

	//intial values
	inp = 64'd410000000;

	#10;

	inp = inp + 1;
	#10;

	inp = inp + 1;
	#10;

	inp = inp + 1;
	#10;

	inp = inp + 1;
	#10;

	inp = inp + 1;
	#10;

	inp = inp + 1;
	#10;

	inp = inp + 10000000;
	#10;

	inp = inp + 10000000;
	#10;


	inp = inp - 1000000;
	#10;

	inp = -64'd1000000000;

	#10;

	inp = inp - 400095;

	#10;




	$finish;


end




endmodule