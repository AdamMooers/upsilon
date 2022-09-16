#pragma once

/* This is a pointer _into_ a buffer. It is increment
 * (and the variable left decremented) after each
 * operation.
 */
struct bufptr {
	char *p;
	size_t left;
};

enum {
	BUF_OK = 0,
	BUF_WRITE_ERR = -1
};

bool buf_read_sock(int sock, struct bufptr *bp);
bool buf_write_sock(int sock, struct bufptr *bp);
int buf_writevf(struct bufptr *bp, const char *fmt, va_list va);
int buf_writef(struct bufptr *bp, const char *fmt, ...);
