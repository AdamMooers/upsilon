#include <zephyr/zephyr.h>
#include <zephyr/sys/printk.h>
#include "buf.h"

int
buf_writevf(struct bufptr *bp, const char *fmt, va_list va)
{
	/* vsnprintk() returns the amount of bytes that would
	 * be stored in the buffer if the buffer was big enough,
	 * excluding the NUL terminator.
	 * The function will _always_ write a NUL terminator
	 * unless bp->left == 0.
	 */
	int w = vsnprintk(bp->p, bp->left, fmt, va);

	if (w < 0)
		return BUF_WRITE_ERR;

	/* Return the number of bytes that are required to be
	 * written.
	 * Do not increment the buffer pointer, the truncated
	 * data may not be safe.
	 * Since w is the amount of required bytes minus the NUL
	 * terminator, w == bp->left is still an out-of-memory
	 * situation.
	 */
	if (w >= bp->left) {
		return w - bp->left + 1;
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
	int r = buf_writevf(bp, fmt, va);
	va_end(va);
	return r;
}
