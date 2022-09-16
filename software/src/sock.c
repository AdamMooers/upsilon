#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

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

bool
client_read_into_buf(int sock, struct clireadbuf *buf)
{
	if (buf->st == MSG_READY) {
		LOG_WRN("%s called while MSG_READY: misuse", __func__);
		return true;
	}

	if (!buf_read_sock(sock, &buf->b))
		return false;

	if (buf->b.left == 0) switch (buf->st) {
	case WAIT_ON_HEADER: {
		uint16_t len;
		memcpy(&len, buf->buf, sizeof(len));
		buf->b.left = ntohs(len);
		buf->st = READING_CLIENT;
		break;
	} case READING_CLIENT:
		buf->st = MSG_READY;
		break;
	}

	return true;
}

void
client_buf_reset(struct clireadbuf *buf)
{
	buf->st = WAIT_ON_HEADER;
	buf->b.p = buf->buf;
	buf->b.left = sizeof(uint16_t);
}
