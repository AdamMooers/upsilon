#pragma once

/* Controller only supports JSON_MAX_LEN JSON tokens.
 * A token is
 * * the beginning of an object
 * * A key
 * * any value
 * * the beginning of an array

Due to a particular quirk of JSMN, the numbers
can also be strings. Numbers MUST be integers.
msgid SHOULD be a small number.

 Messages are formatted like
{
	"version" : num, // required, set to 0
	"msgid" : str, // optional
	"error" : str, // only from controller, ignored from computer

	// and zero to one of
	"ident" : null,
	"consts" : { // all are optional
		"P" : num,
		"I" : num,
		"Vnm" : num
	}, // or null
	"ramp" : {
		"dac" : num,
		"off" : num,
		"dly" : num
	},
	"read_adc" : num,
	"reset_dac" : num,
	"reset_all" : null,
	"startscan" : null, // from computer
	"startscan" : { // from controller
		"id" : int,
		"blksiz" : int,
		"blklen" : int
	}
}

Both the controller and the computer read and write these messages.
*/

#define JSON_MAX_LEN 32

enum msg_ret {
	MSG_OK,
	MSG_BAD_JSON,
	MSG_SOCKERR
};

enum msg_ret msg_parse_dispatch(int client, struct readbuf *buf);
