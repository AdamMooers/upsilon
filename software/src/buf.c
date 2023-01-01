#include <zephyr/zephyr.h>
#include <zephyr/sys/printk.h>
#include <zephyr/net/socket.h>
#include "buf.h"

bool
buf_read_sock(int sock, struct bufptr *bp)
{
	if (bp->left < 2)
		return false;

	ssize_t l = zsock_recv(sock, bp->p, bp->left - 1, 0);
	if (l < 0)
		return false;

	bp->left -= l;
	bp->p += l;
	*bp->p = 0;
	return true;
}

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
	int r;
	va_list va;
	va_start(va, fmt);
	r = buf_writevf(bp, fmt, va);
	va_end(va);
	return r;
}
