#pragma once
#include "buf.h"
int server_init_sock(int port);
int server_accept_client(int server);

#define CLIREADBUF_SIZ 1024
enum clireadbuf_state {
	WAIT_ON_HEADER,
	READING_CLIENT,
	MSG_READY
};
struct clireadbuf {
	struct bufptr b;
	enum clireadbuf_state st;
	char buf[CLIREADBUF_SIZ];
};

bool client_read_into_buf(int sock, struct clireadbuf *buf);
void client_buf_reset(struct clireadbuf *buf);
