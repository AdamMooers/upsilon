#include <zephyr/zephyr.h>
#include <zephyr/sys/printk.h>
#include <zephyr/net/socket.h>
#include "buf.h"

/* Read from the socket into the buffer.
 * This function is meant to be called multiple times on the
 * same struct. The controller loads bp->left with the amount
 * of bytes it wishes to read, and continues until bp->left == 0.
 *
 * This function returns false if there was an error reading
 * from the socket.
 * A read of 0 bytes returns true.
 */
bool
buf_read_sock(int sock, struct bufptr *bp)
{
	ssize_t l = zsock_recv(sock, bp->p, bp->left, 0);
	if (l < 0)
		return false;

	bp->left -= l;
	bp->p += l;
	return true;
}

/* Write from the bufptr into a socket.
 * This function is meant to be called once per prepared bufptr.
 *
 * This function returns false if there was an error on the
 * socket.
 */
bool
buf_write_sock(int sock, struct bufptr *bp)
{
	while (bp->left) {
		ssize_t l = zsock_send(sock, bp->p, bp->left, 0);
		if (l < 0)
			return false;
		bp->p += l;
		bp->left -= l;
	}

	return true;
}

/* Write a formatted string to bp.
 * This function uses printf(), which means that it deals with
 * writing _C-strings_, not unterminated buffers.
 * When using this function, the buffer must be _one more_ than
 * the maximum message length. For instance, a 1024-byte message
 * should be in a 1025-byte buffer. HOWEVER, bp->left must still
 * be set to the total length of the buffer (in the example, 1025).
 *
 * The final bufptr points to the NUL terminator, so that it
 * is overwritten on each call to the function.
 *
 * This function returns 0 for a successful write, -1 for an
 * encoding error (should never happen), and a positive value
 * for the amount of bytes that could not fit.
 */
int
buf_writevf(struct bufptr *bp, const char *fmt, va_list va)
{
	int w;

	/* vsnprintk() returns the amount of bytes that would
	 * be stored in the buffer if the buffer was big enough,
	 * excluding the NUL terminator.
	 * The function will _always_ write a NUL terminator
	 * unless bp->left == 0.
	 */
	w = vsnprintk(bp->p, bp->left, fmt, va);

	if (w < 0)
		return BUF_WRITE_ERR;

	if (w >= bp->left) {
		size_t oldleft = bp->left;
		buf->p += bp->left - 1;
		bp->left = 1;
		return w - oldleft + 1;
	} else {
		bp->p += w;
		bp->left -= w;
		return BUF_OK;
	}
}

int
buf_writef(struct bufptr *bp, const char *fmt, ...)
{
	va_list va;
	va_start(va, fmt);
	buf_writevf(bp, fmt, va);
	va_end(va);
}
