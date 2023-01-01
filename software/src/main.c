#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "sock.h"
#include "buf.h"

#define LSC_IMPLEMENTATION
#include "lsc.h"

LOG_MODULE_REGISTER(main);

#define PORT 6626

enum {
	IDENT,
	ADC,
	DAC,

	CL_SETPT,
	CL_P,
	CL_I,
	CL_ARM,
	CL_ERR,
	CL_Z,
	CL_CYCLES,
	CL_DELAY,

	RASTER_MAX_SAMPLES,
	RASTER_MAX_LINES,
	RASTER_SETTLE_TIME,
	RASTER_DX,
	RASTER_DY,
	RASTER_USED_ADCS,
	RASTER_ARM,

	ARGS_NUM
};

static int _strcmp(const void *p1, const void *p2) {return strcmp(p1,p2);}

static int
client_exec(int sock, struct lsc_line *l)
{
	static char buf[4096];
#	define stringify(s) #s
#	define mkid(s) [s] = stringify(s)
	static const char *argnames[ARGS_NUM] = {
		mkid(IDENT),
		mkid(ADC),
		mkid(DAC),

		mkid(CL_SETPT),
		mkid(CL_P),
		mkid(CL_I),
		mkid(CL_ARM),
		mkid(CL_ERR),
		mkid(CL_Z),
		mkid(CL_CYCLES),
		mkid(CL_DELAY),

		mkid(RASTER_MAX_SAMPLES),
		mkid(RASTER_MAX_LINES),
		mkid(RASTER_SETTLE_TIME),
		mkid(RASTER_DX),
		mkid(RASTER_DY),
		mkid(RASTER_USED_ADCS),
		mkid(RASTER_ARM)
	};
#	undef mkid
#	undef stringify

	char **p = bsearch(l->buf[l->name], argnames, ARGS_NUM,
	                  sizeof(argnames[0]), _strcmp);
	if (!p) {
		sock_name_printf(sock, l, buf, sizeof(buf),
		                 "ERROR\tunknown command\n");
		return 0;
	}

	switch (p - argnames) {

	}
}

static void
client_parse(int cli)
{
	static char buf[LSC_MAXBUF];
	static struct bufptr bp = {buf, sizeof(buf)};
	static struct lsc_parser psr = {0};
	static bool first = true;
	struct lsc_line l;

	if (first) {
		lsc_reset(&psr, buf);
		first = false;
	}

	switch (lsc_read(&psr, &l)) {
	case LSC_OVERFLOW:
		LOG_ERR("client command overflow\n");
		break;
	case LSC_OVERFLOW:
		LOG_ERR("client command argument overflow\n");
		break;
	case LSC_INVALID_ARGUMENT:
		LOG_ERR("programmer misuse");
		break;
	case LSC_COMPLETE:
		// process
		lsc_reset(&psr, buf);
		break:
	}
}

static void
process_client(int cli)
{
	enum fds {
		CLIENT_FD,
		SCANDATA_FD,
		MAXFDS
	};
	struct zsock_pollfd fds[MAXFDS] = {0};

	fds[CLIENT_FD].fd = cli;
	fds[CLIENT_FD].events = ZSOCK_POLLIN;
	// Currently not used
	fds[SCANDATA_FD].fd = -1;

	while (zsock_poll(fds, MAXFDS, 0) >= 0) {
		if (fds[CLIENT_FD].revents | POLLIN)
			client_parse(cli);
	}
}

void
main(void)
{
	int srv = server_init_sock(PORT);

	for (;;) {
		int cli = server_get_client(server_sock);
		process_client(cli);
		LOG_INF("Closing client socket");
		zsock_close(cli);
	}
}
