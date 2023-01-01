#ifndef LSC
#define LSC
#include <stddef.h>

#ifndef LSC_MAXARG
# define LSC_MAXARG 32
#endif

#ifndef LSC_MAXBUF
# define LSC_MAXBUF 1024
#endif

struct lsc_line {
	size_t name;
	char *buf[LSC_MAXARG];
	size_t len;
};

struct lsc_parser {
	int state;

	char intbuf[LSC_MAXBUF];
	size_t len;

	char *rptr;
};

enum lsc_r {
	LSC_MORE,
	LSC_OVERFLOW,
	LSC_ARG_OVERFLOW,
	LSC_INVALID_ARGUMENT,
	LSC_COMPLETE
};

void lsc_reset(struct lsc_parser *, char *);
enum lsc_r lsc_read(struct lsc_parser *,
                    struct lsc_line *);
static void lsc_load_ptr(struct lsc_parser *in, char *p) {
	in->rptr = p;
}

#endif
#ifdef LSC_IMPLEMENTATION

enum { LSC_READ, LSC_DISCARD };

static void reset_parse_state(struct lsc_parser *in) {
	in->state = LSC_READ;
	in->len = 0;
}

void lsc_reset(struct lsc_parser *in, char *p) {
	reset_parse_state(in);
	in->rptr = p;
}

static enum lsc_r lsc_parse(struct lsc_parser *in,
                            struct lsc_line *line) {
	char *s = in->intbuf;
	enum lsc_r r = LSC_ARG_OVERFLOW;

	line->name = (*s == ':');
	line->len = 0;

	while (line->len < LSC_MAXARG) {
		line->buf[line->len++] = s;
		for (; *s && *s != '\t'; s++);

		if (!*s) {
			r = LSC_COMPLETE;
			break;
		} else {
			*s = 0;
			s++;
		}
	}

	reset_parse_state(in);
	return r;
}

enum lsc_r lsc_read(struct lsc_parser *psr,
                    struct lsc_line *line) {
	char c;

	if (!psr || !psr->rptr || !line)
		return LSC_INVALID_ARGUMENT;

	while ((c = *psr->rptr)) {
		psr->rptr++;
		if (psr->state == LSC_DISCARD) {
			if (c == '\n') {
				reset_parse_state(psr);
				return LSC_OVERFLOW;
			}
		} else {
			switch (c) {
			case '\n':
				psr->intbuf[psr->len] = 0;
				return lsc_parse(psr, line);
			default:
				if (psr->len == LSC_MAXBUF)
					psr->state = LSC_DISCARD;
				psr->intbuf[psr->len++] = c;
			}
		}
	}

	return LSC_MORE;
}
#endif
