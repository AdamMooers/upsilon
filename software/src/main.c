#include <zephyr/zephyr.h>
#include <errno.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

#include "upsilon.h"
#include "access.h"
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
	int e = sock_read_buf(s, &bp, true);
	if (e != 0)
		return e;
	return (unsigned char)buf[0] | (unsigned char) buf[1] << 8;
}

static const char *const compiler_ret_str[CREOLE_COMPILER_RET_LEN] = {
	[CREOLE_COMPILE_OK] = "compile ok",
	[CREOLE_OPCODE_READ_ERROR] = "opcode read error",
	[CREOLE_OPCODE_MALFORMED] = "opcode malformed",
	[CREOLE_ARG_READ_ERROR] = "arg read error",
	[CREOLE_ARG_MALFORMED] = "arg malformed",
	[CREOLE_LAST_READ_ERROR] = "last read error",
	[CREOLE_LAST_MALFORMED] = "last malformed",
	[CREOLE_DATA_OVERFLOW] = "data overflow",
	[CREOLE_TYPE_ERROR] = "type error",
	[CREOLE_PROGRAM_OVERFLOW] = "program overflow"
}

static const char *const run_ret_str[CREOLE_RUN_RET_LEN] = {
	[CREOLE_STEP_CONTINUE] = "continue",
	[CREOLE_STEP_SYSCALL] = "syscall",
	[CREOLE_STEP_STOP] = "stop",
	[CREOLE_STACK_OVERFLOW] = "overflow",
	[CREOLE_STACK_UNDERFLOW] = "underflow",
	[CREOLE_RUN_DECODE_ERROR] = "decode error",
	[CREOLE_REGISTER_OVERFLOW] = "register overflow",
	[CREOLE_STEP_UNKNOWN_OPCODE] = "unknown opcode",
	[CREOLE_DIV_BY_ZERO] = "div by zero",
	[CREOLE_STEP_HIGH_BIT_MALFORMED] = "high bit malformed",
	[CREOLE_JUMP_OVERFLOW] = "jump overflow"
};

static int
hup(int sock)
{
	struct zsock_pollfd fd = {
		.fd = sock,
		.events = POLLHUP,
		.revents = 0
	};

	return zsock_pollfd(&fd, 1, 0);
}

static void
exec_creole(unsigned char *buf, int size, int sock)
{#define DATLEN 64
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

	int e = creole_compile(&env);
	if (e != CREOLE_COMPILE_OK) {
		LOG_WRN("%s: compile: %s at %zu", get_thread_name(),
		        compiler_ret_str[e],
		        (env.r_start.left - env.r_current.left));
		return;
	}

	for (;;) {
		creole_word sc;
		e = creole_step(&env, &sc);
		switch (e) {
		case CREOLE_STEP_CONTINUE:
			continue;
		case CREOLE_STEP_SYSCALL:
			LOG_WRN("%s: syscall unsupported", get_thread_name());
			continue;
		case CREOLE_STEP_STOP:
			return;
		default:
			LOG_WRN("%s: run: %s", get_thread_name(),
			        creole_run_ret[e]);
			return;
		}

		if (hup(sock) != 0) {
			LOG_WRN("%s: hangup", get_thread_name());
			return;
		}
	}
}

static void
exec_entry(void *client_p, void *threadnum_p,
           void *unused __attribute__((unused)))
{
	intptr_t client = client_p;
	intptr_t threadnum = threadnum_p;
	int size = read_size(client);

	const char thread_name[64];
	vsnprintk(thread_name, sizeof(thread_name), "%d:%d", client, threadnum);
	k_thread_name_set(k_current_get(), thread_name);

	LOG_INF("%s: Connection initiated", thread_name);

	if (size < 0) {
		LOG_WRN("%s: error in read size: %d", get_thread_name(), size);
		zsock_close(client);
		return;
	}

	struct bufptr bp = {readbuf[threadnum], size};
	int e = sock_read_buf(client, &bp, true);
	if (e != 0) {
		LOG_WRN("%s: error in read body: %d", get_thread_name(), e);
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
	static unsigned int connection_counter = 0;
	for (;;) {
		int client = server_accept_client(srvsock);
		int i;

		for (i = 0; i < THREADNUM; i++) {
			if (!thread_ever_used[i]
			    || k_thread_join(threads[i], 0) == 0) {
				connection_counter++;
				k_thread_create(threads[i], stacks[i],
				THREAD_STACK_SIZ, exec_entry,
				(uintptr_t) client, (uintptr_t) i,
				(uintptr_t) connection_counter,
				1, 0, K_NO_WAIT);
			}
		}

		if (i == THREADNUM) {
			LOG_INF("Too many connections (max %d)",
			        THREADNUM);
			zsock_close(client);
		}
	}
}

void
main(void)
{
	access_init();
	k_thread_name_get(k_current_get(), "main thread");
	for (;;) {
		int sock = server_init_sock(6626);
		main_loop(sock);
		zsock_close(sock);
	}
}
