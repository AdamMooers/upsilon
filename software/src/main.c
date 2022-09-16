#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "sock.h"

LOG_MODULE_REGISTER(main);

#define PORT 6626
enum fds {
	CLIENT_FD,
	SCANDATA_FD,
	MAXFDS
};

static void
process_client(int cli)
{
	struct zsock_pollfd fds[MAXFDS] = {0};
	struct clireadbuf readbuf = {0};

	client_buf_reset(&readbuf);

	fds[CLIENT_FD].fd = cli;
	fds[CLIENT_FD].events = ZSOCK_POLLIN;
	// Currently not used
	fds[SCANDATA_FD].fd = -1;

	while (zsock_poll(fds, MAXFDS, 0) >= 0) {
		if (fds[CLIENT_FD].revents | POLLIN) {
			if (!client_read_into_buf(cli, &readbuf)) {
				INFO_WRN("client_read_into_buf: %d", errno);
				goto cleanup;
			}

			if (readbuf.st == MSG_READY) {
				msg_parse_dispatch(cli, &readbuf);
				client_buf_reset(&buf);
			}
		}
	}
cleanup:
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
