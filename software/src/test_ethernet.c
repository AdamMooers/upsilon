#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/zephyr.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(test_ethernet);

#define PORT 6626

static int
ip_init(void)
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
		.sin_port = htons(PORT)
	};

	if (zsock_bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		LOG_ERR("error: bind: %d", errno);
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}

	if (zsock_listen(sock, 2) < 0) {
		LOG_ERR("error: listen: %d", errno);
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}

	return sock;
}

static int
get_client(int server)
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
	LOG_PRINTK("Connection: %s\n", ipaddr);
	return client;
}

static int
send_all(int sock, char *buf, int len)
{
	do {
		int sent = zsock_send(sock, buf, len, 0);
		if (sent < 0) {
			LOG_WRN("error in send: %d", errno);
			return 0;
		}
		buf += sent;
		len -= sent;
	} while (len > 0);
	return 1;
}

static void
print_buf_escaped(const char *buf, size_t len)
{
	for (size_t i = 0; i < len; i++) {
		if (*buf < 0x20 || *buf >= 0x7F)
			LOG_PRINTK("[%02x]", *buf);
		else
			LOG_PRINTK("%c", *buf);
	}
}

static void
client_comm(int sock)
{
	for (;;) {
		char buf[256];
		ssize_t len = zsock_recv(sock, buf, sizeof(buf), 0);

		if (len < 0) {
			LOG_WRN("Error in client socket: %d", errno);
			return;
		} else if (len == 0) {
			LOG_INF("Client disconnected");
			return;
		}
		print_buf_escaped(buf, len);
		if (!send_all(sock, buf, len))
			return;
	}
}

/* DHCP is done before main(), so no manual DHCP setup required. */

void
main(void)
{
	LOG_PRINTK("Init test server...\n");
	int server_sock = ip_init();
	LOG_PRINTK("Test server waiting on %d\n", PORT);

	for (;;) {
		int client_sock = get_client(server_sock);
		client_comm(client_sock);
		zsock_close(client_sock);
	}
}
