#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include "sock.h"
#include "buf.h"

LOG_MODULE_REGISTER(sock);

int
server_init_sock(int port)
{
	int sock;

	sock = zsock_socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

	if (sock < 0) {
		LOG_ERR("error: socket: %d", sock);
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}

	struct sockaddr_in addr = {
		.sin_family = AF_INET,
		.sin_addr = {.s_addr = htonl(INADDR_ANY)},
		.sin_port = htons(port)
	};

	if (zsock_bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		LOG_ERR("error: bind: %d", errno);
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}

	if (zsock_listen(sock, 2) < 0) {
		LOG_ERR("error: listen: %d", errno);
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}

	LOG_INF("Upsilon waiting on %d", port);

	return sock;
}

int
server_accept_client(int server)
{
	int client;
	struct sockaddr_in addr;
	socklen_t len = sizeof(addr);

	/* Accept clients in a loop. This should block when there are no clients
	 * so other threads can run.
	 */
	do {
		client = zsock_accept(server, (struct sockaddr *)&addr, &len);
		if (client < 0)
			LOG_WRN("error in accept: %d", errno);
	} while (client < 0);

	char ipaddr[32];
	zsock_inet_ntop(addr.sin_family, &addr.sin_addr, ipaddr, sizeof(ipaddr));
	LOG_INF("Connection received from %s", ipaddr);
	return client;
}

bool
sock_read_buf(int sock, struct bufptr *bp, bool entire)
{
	if (bp->left < 2)
		return false;

	do {
		ssize_t l = zsock_recv(sock, bp->p, bp->left - 1, 0);
		if (l < 0)
			return false;

		bp->left -= l;
		bp->p += l;
	} while (entire && bp->left > 0);

	return true;
}

bool
sock_write_buf(int sock, struct bufptr *bp)
{
	/* Since send may not send all data in the buffer at once,
	 * loop until it sends all data (or fails).
	 */
	while (bp->left) {
		ssize_t l = zsock_send(sock, bp->p, bp->left, 0);
		if (l < 0)
			return false;
		bp->p += l;
		bp->left -= l;
	}

	return true;
}

int
sock_vprintf(int sock, struct bufptr *bp, const char *fmt, va_list va)
{
	int r = buf_writevf(bp, fmt, va);
	struct bufptr store_bp = *bp;
	if (r != BUF_OK)
		return r;

	/* The difference between the initial and final values of
	 * `left` is the amount of bytes written to the buffer.
	 * Set left to this difference so that the only thing sent
	 * is the bytes written by buf_writevf.
	 */
	store_bp.left -= bp->left;
	if (!sock_write_buf(sock, &store_bp)) {
		return BUF_SOCK_ERR;
	} else {
		return BUF_OK;
	}
}

int
sock_printf(int sock, struct bufptr *bp, const char *fmt, ...)
{
	va_list va;
	va_start(va, fmt);
	bool b = sock_vprintf(sock, bp, fmt, va);
	va_end(va);
	return b;
}
