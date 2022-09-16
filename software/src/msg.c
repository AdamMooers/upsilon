#include <zephyr.h>
#include <zephyr/net/socket.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <stdarg.h>

#define JSMN_PARENT_LINKS
#define JSMN_STRICT
#define JSMN_STATIC
#include "jsmn.h"
#include "sock.h"
#include "buf.h"

LOG_MODULE_REGISTER(msg);

enum cmdtype {
	NONE,
	IDENT,
	CONSTS,
	RAMP,
	READ_ADC,
	RESET_DAC,
	RESET,
	CMDTYPE_LEN
};

struct cmd {
	enum cmdtype typ;
	char *version;
	char *msgid;
	char *emsg;
	union {
		char *ident;
		struct {
			int P;
			int I;
			int Vnm;
		} consts;
		struct {
			int dac;
			int offset;
			int dely;
		} rampcmd;
		int read_adc;
		int reset_dac;
		struct {
			int id;
			int blklen;
			int siz;
		} startscan;
	};
};

struct parser {
	struct readbuf *js; // JSON buffer.
	jsmntok_t *ctok; // Parser is at this token.
	jsmntok_t *last; // Last token in the sequence.
	int cli; // Socket.
	struct cmd cmd; // Command parsed into.
};

enum {
	OK = 0,
	CONVERR = BUF_WRITE_ERR,
	SOCKERR = BUF_WRITE_ERR - 1
};

// Serialize struct cmd into JSON and send it.
static int
dispatch(int sock, struct cmd *cmd)
{
	// Add byte for NUL terminator for snprintf()
	char buf[CLIREADBUF_SIZ + sizeof(uint16_t) + 1] = {0};
	struct bufptr bp = {buf, sizeof(buf)};
	int r;

	/* If no version could be read (i.e. sending a message
	 * saying that the JSON was invalid) then send a
	 * version 0 message.
	 */
	if (!cmd->version)
		cmd->version = "0";

	if ((r = buf_writef(&bp, "{\"version\":\"%s\"", cmd->version)) != BUF_OK)
		return r;

	if (cmd->msgid) {
		if ((r = buf_writef(&bp, ",\"msgid\":\"%s\"", cmd->msgid)) != BUF_OK)
			return r;
	}
	if (cmd->emsg) {
		if ((r = buf_writef(&bp, ",\"error\":\"%s\", cmd->emsg)) != BUF_OK)
			return r;
		goto send;
	}

	if (!cmd->emsg) switch (cmd->typ) {
	case IDENT:
		if ((r = buf_writef(&bp, ",\"%s\":\"%s\", sl[IDENT].s, "cryosnom") != 0)
			return r;
		goto send;
	case CONSTS:
		// STUB
		goto send;
	case RAMPCMD:
		// STUB
		goto send;
	case READ_ADC:
		// STUB
		goto send;
	case READ_DAC:
		// STUB
		goto send;
	case STARTSCAN:
		// STUB
		goto send;
	}

send:
	if ((r = buf_writef(&bp, "}")) != 0)
		return r;

	struct bufptr wptr = {buf, sizeof(buf) - bp.left};
	if (!buf_write_sock(sock, &wptr))
		return SOCKERR;
	return OK;
}

static inline bool
eq(jsmntok_t *tk, char *buf, const char *s, size_t slen)
{
	return (slen == buf->end - buf->start
			&& strncasecmp(s, &jr->js[buf->start], slen) == 0);
}
#define liteq(buf,tok,st) liteq((buf), (tok), (st), sizeof(st) - 1)

static inline void
jsmn_term(char *buf, jsmntok_t *tok)
{
	buf[tok->end] = 0;
}

static jsmntok_t
parse_consts(int sock, jsmntok_t *ct, int len, char *js)
{
	while (len > 0) {
		if (liteq(ct, js, "P")) {
			ct++;
			len--;
			if (
}

static bool
parse(int sock, jsmntok_t *first, jsmntok_t *last, char *js)
{
	if (first->type != JSMN_OBJECT) {
		psr->obj.emsg = "malformed json (not an object)";
		goto fail;
	}

	for (jsmntok_t *ct = first; ct < psr->last; ct++) {
		if (liteq(ct, js, "version")) {
			ct++;
			if (!liteq(ct, js, "0")) {
				psr->obj.emsg = "invalid version";
				goto fail;
			}
			jsmn_term(js, ct);
			psr->version = js + ct->start;
		} else if (liteq(ct, js, "msgid")) {
			ct++;
			jsmn_term(js, ct);
			psr->msgid = js + ct->start;
		} else if (liteq(ct, js, "ident")) {
			ct++;
			psr->typ = IDENT;
		} else if (liteq(ct, js, "consts")) {
			ct++;
			psr->typ = CONSTS;
			if (ct->type == JSMN_OBJECT) {
				if (!(ct = parse_consts(sock, ct+1, ct->size, js)))
					goto fail;
			}
		}
	}

fail:
	return dispatch(&psr->obj);
}

/* Read a JSON message, parse it, execute it, and respond to it.
 */
bool
msg_parse_dispatch(int cli, struct readbuf *buf)
{
	jsmn_parser psr;
	jsmntok_t tokens[JSON_MAX_LEN];

	struct cmd cmd = {
		.typ = NONE
	};

	jsmn_init(&psr);

	if (jsmn_parse(buf->buf, buf->readlen, &tokens, JSON_MAX_LEN) < 0) {
		psr.emsg = "malformed json";
		return dispatch(cli, &cmd);
	}

	return parse(cli, &tokens[0], &tokens[JSON_MAX_LEN-1], buf);
}
