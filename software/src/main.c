#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "sock.h"
#include "buf.h"

LOG_MODULE_REGISTER(main);

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
	int srv = server_init_sock(6626);

	for (;;) {
		int cli = server_get_client(server_sock);
		process_client(cli);
		LOG_INF("Closing client socket");
		zsock_close(cli);
	}
}
