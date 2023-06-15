/* Copyright 2022 (C) Peter McGoron
 * Copyright 2022 (C) Nicolas Azzi
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
#include <memory>
#include <limits>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <iostream>
#include <random>
#include <unistd.h>

// Other classes implemented (Verilator)
#include <verilated.h>
#include "control_loop_math_implementation.h"
#include "control_loop_cmds.h"
#include "Vcontrol_loop_sim_top.h"
using ModType = Vcontrol_loop_sim_top;

// Clock
uint32_t main_time = 0;
double sc_time_stamp() {
	return main_time;
}

ModType *mod;

static void run_clock() {
	for (int i = 0; i < 2; i++) {
		mod->clk = !mod->clk;
		mod->eval();
		main_time++;
	}
}

static void init(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);
	mod = new ModType;
	mod->clk = 0;
}

static void set_value(V val, unsigned name) {
	mod->cmd = CONTROL_LOOP_WRITE_BIT | name;
	mod->word_into_loop = val;
	mod->start_cmd = 1;

	do { run_clock(); } while (!mod->finish_cmd);
	mod->start_cmd = 0;
	run_clock();
}

int main(int argc, char **argv) {
	init(argc, argv);

	int Con,				// Continue option for user
	P = 3,					// Default P value
	I = 0,					// Default I value
 	Delay = 20,				// Default Delay value
	SetPt = 10000,			// Default SetPt value
	Status = 1,				// Default Status value
	Option_Picked;			// Option user picked
	
	do
	{

		mod = new ModType;
		Transfer func = Transfer{150, 0, 2, 1.1, 10, -1};

		mod->clk = 0;

		// Testing this char for P value
		char Data_Change_S = '0b11010111000010100011110101110000101000111';

		// Default value for P, some type of error where it won't accept any string, int | Try char next time
		set_value(0b11010111000010100011110101110000101000111, CONTROL_LOOP_P);

		// Default value
		set_value((V)6 << CONSTS_FRAC, CONTROL_LOOP_I);
		set_value(Delay, CONTROL_LOOP_DELAY);
		set_value(SetPt, CONTROL_LOOP_SETPT);
		set_value(Status, CONTROL_LOOP_STATUS);

		// Menu
		do
		{
			printf("%15s\n", "Menu");
			printf("1) Set Control loop P    Current value: %d\n", P);
			printf("2) Set Control loop I    Current value: %d\n", I);
			printf("3) Set Delay             Current value: %d\n", Delay);
			printf("4) Set setpoint          Current value: %d\n", SetPt);
			printf("5) Set status            Current value: %d\n", Status);
			printf("6) Continue\n");

			// Checks for what option user picks
			scanf("%d", &Option_Picked);
			
			// Clears unix screen
			system("clear");

			switch (Option_Picked)
			{
			case 1:
				// This case doesn't work for some reason? Need further time to figure it out
				printf("Please input new Control Loop P value: ");
				scanf("%d", &P);
				set_value(P, CONTROL_LOOP_P);
				break;
			case 2:
				printf("Please input new Control Loop I value: ");
				scanf("%d", &I);
				set_value(I, CONTROL_LOOP_I);
				break;
			case 3:
				printf("Please input new delay value: ");
				scanf("%d", &Delay);
				set_value(Delay, CONTROL_LOOP_DELAY);
				break;
			case 4:
				printf("Please input new setpoint value: ");
				scanf("%d", &SetPt);
				set_value(SetPt, CONTROL_LOOP_SETPT);
				break;
			case 5:
				printf("Please input new status value: ");
				scanf("%d", &Status);
				set_value(Status, CONTROL_LOOP_STATUS);
				break;
			}

		} while (Option_Picked != 6);




		mod->curset = 0;

		// Resets Con to 1 to activate for loop
		Con = 1;

		for (int tick = 0; Con == 1; tick++) {
			run_clock();
			if (mod->request && !mod->fulfilled) {
				/* Verilator values are not sign-extended to the
				* size of type, so we have to do that ourselves.
				*/
				V ext = sign_extend(mod->curset, 20);
				V val = func.val(ext);
				printf("setting: %ld, val: %ld\n", ext, val);
				mod->measured_value = val;
				mod->fulfilled = 1;
			} else if (mod->fulfilled && !mod->request) {
				mod->fulfilled = 0;
			}

			if (mod->finish_cmd) {
				mod->start_cmd = 0;
			}

			// After 100000 ticks shows user prompt, might make tick to be changable for user.
			if (tick % 100000 == 0 && tick != 0)
			{
				printf("Continue? (0 for exit, 1 for yes, 2 to return to menu)\n");
				scanf("%d", &Con);
			}
		}
		// Clears unix screen
		system("clear");

		mod->final();
		delete mod;
	} while (Con == 2);
	
	return 0;
}
