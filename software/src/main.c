#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "sock.h"
#include "buf.h"

LOG_MODULE_REGISTER(main);

#define THREAD_STACK_SIZ 1024*32
#define THREADNUM 32
static K_KERNEL_STACK_ARRAY_DEFINE(stacks, THREADNUM, THREAD_STACK_SIZ);

#define READBUF_SIZ 0xFFFF
static unsigned char readbuf[THREADNUM][READBUF_SIZ];
static struct kthread_t threads[THREADNUM];
static bool thread_ever_used[THREADNUM];

static int
read_size(int s)
{
	char buf[2];
	struct bufptr bp = {buf, sizeof(buf)};

	if (!sock_read_buf(s, &bp, true))
		return -1;
	return (unsigned char)buf[0] | (unsigned char) buf[1] << 8;
}

static void
exec_creole(unsigned char *buf, int size, int sock)
{
#define DATLEN 64
	struct creole_reader dats[DATSLEN];
#define REGLEN 32
	creole_word reg[REGLEN];
#define STKLEN 1024
	creole_word stk[STKLEN];

	struct creole_env env = {
		.dats = dats,
		.datlen = DATLEN,
		.reg = reg,
		.reglen = REGLEN,
		.stk = stk,
		.stklen = STKLEN,

		.r_current = {buf, size},
		.r_start = {buf, size},
		.sock = sock
	};

}

/* TODO: error messages */

static void
exec_entry(void *client_p, void *threadnum_p,
           void *unused __attribute__((unused)))
{
	intptr_t client = client_p;
	intptr_t threadnum = threadnum_p;
	int size = read_size(client);

	if (size < 0) {
		zsock_close(client);
		return;
	}

	struct bufptr bp = {readbuf[threadnum], size};
	if (!sock_read_buf(client, &bp, true)) {
		zsock_close(client);
		return;
	}

	exec_creole(size);
	zsock_close(client);
}

/* TODO: main thread must be higher priority than execution threads */
static void
main_loop(int srvsock)
{
	for (;;) {
		int client = server_accept_client(srvsock);
		int i;

		for (i = 0; i < THREADNUM; i++) {
			if (!thread_ever_used[i]
			    || k_thread_join(threads[i], 0) == 0) {
				k_thread_create(threads[i], stacks[i],
				THREAD_STACK_SIZ, exec_entry,
				(uintptr_t) client, (uintptr_t) i, NULL,
				1, 0, K_NO_WAIT);
			}
		}

		if (i == THREADNUM) {
			LOG_INF("Too many connections (max %d)",
			        THREADNUM);
		}
	}
}

void
main(void)
{
	for (;;) {
		int sock = server_init_sock(6626);
		main_loop(sock);
		close(sock);
	}
}
