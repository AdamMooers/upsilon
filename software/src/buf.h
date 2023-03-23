#pragma once

/* This is a pointer _into_ a buffer. It is incremented (and the variable
 * "left" decremented) after each operation.
 *
 * Space is always left for a NUL terminator.
 */
struct bufptr {
	char *p;
	size_t left;
};

enum {
	BUF_OK = 0,
	BUF_WRITE_ERR = -1,
	BUF_SOCK_ERR = -2
};

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
int buf_writevf(struct bufptr *bp, const char *fmt, va_list va);
int buf_writef(struct bufptr *bp, const char *fmt, ...);
