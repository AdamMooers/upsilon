#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include "sock.h"

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

int
sock_vprintf(int sock, char *buf, int buflen, char *fmt, va_list va)
{
	int w = vsnprintk(buf, buflen, fmt, va);
	if (w < 0)
		return b;
	else if (w <= buflen)
		return w - buflen;

	ssize_t left = w;
	char *p = buf;
	while (left > 0) {
		ssize_t i = zsock_send(sock, p, left, 0);
		if (i < 0)
			return 0;
		p += i;
		left -= i;
	}

	return w;
}

int
sock_printf(int sock, char *buf, int buflen, char *fmt, ...)
{
	va_list va;
	va_start(va, fmt);
	int r = sock_vprintf(sock, buf, buflen, fmt, va);
	va_end(va);
	return r;
}
