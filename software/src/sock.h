#pragma once
#include <stdarg.h>
#include "buf.h"

/* Initialize server to listen on the port passed as an argument.
 */
int server_init_sock(int port);

/* Accept a client and allocate a file descriptor for the client.
 */
int server_accept_client(int server);

/* Read data into buffer. Returns 0 if buffer is filled. This is
 * raw binary (no NUL termination).
 */
int sock_read_buf(int sock, struct bufptr *bp, bool entire);

/* Write raw buffer data into socket. This data is raw binary and
 * does not have to be NUL terminated. Returns 0 when all data has
 * been written.
 */
int sock_write_buf(int sock, struct bufptr *bp);

/* Write formatted string into socket. The user must provide a
 * buffer into which the formatted string is written. These return
 * with a buf.h error, or BUF_OK when successful.
 */
int sock_vprintf(int sock, struct bufptr *bp, const char *fmt, va_list va);
int sock_printf(int sock, struct bufptr *bp, const char *fmt, ...);
