#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>
#include <string.h>
#include "libkcode/libkcode.h"

#define BLOCK_SIZE 1024

SV* kc_replace(unsigned char*, SV*, int, int);

/*-------------------------------------------------------------------*/

SV* kc_replace(unsigned char* buf, SV* hash_r, int maxlen, int code) {
	unsigned char* newbuf;
	unsigned char* newbuf0;
	unsigned char np[1];
	int c = 0;
	int sz, i, bsize;
	STRLEN len;
	char* stp;
	SV** svpp;
	HV* hash;
	*np = 0;
	
	// 引数がハッシュへの参照かチェック
	if (SvROK(hash_r) && SvTYPE(SvRV(hash_r)) == SVt_PVHV)
		hash = (HV*) SvRV(hash_r);
	else
		return(newSVpv(np, 0));
	
	// バッファサイズを設定
	if (maxlen < 0) return(newSVpv(np, 0));
	if (maxlen == 0) {
		bsize = (((int) (strlen(buf) / BLOCK_SIZE)) + 1) * BLOCK_SIZE;
	} else {
		bsize = maxlen;
	}
	
	// 初期バッファを作成
	if (!(newbuf = malloc(bsize))) return(newSVpv(np, 0));
	*newbuf = 0;
	newbuf0 = newbuf;
	
	// 変換
	
	sz = code ? kcode_charsize_s(buf) : kcode_charsize_e(buf);
	while ((!maxlen || c + abs(sz) <= maxlen) && *buf) {
		if (sz < 0) {
			buf -= sz;
			sz = code ? kcode_charsize_s(buf) : kcode_charsize_e(buf);
			continue;
		}
		if (c + sz > bsize) {
			while (c + sz > bsize) {
				bsize += BLOCK_SIZE;
			}
			if (!(newbuf = malloc(bsize))) return(newSVpv(np, 0));
			memcpy(newbuf, newbuf0, c);
			free(newbuf0);
			newbuf0 = newbuf;
		}
		svpp = hv_fetch(hash, buf, sz, 0);
		if (svpp && SvPOK(*svpp)) {
			stp = SvPV(*svpp, len);
			memcpy(newbuf, stp, len);
			newbuf += len;
			c      += len;
			buf    += sz;
		} else {
			for (i = 0; i < sz; i++) {
				*newbuf++ = *buf++;
				c++;
			}
		}
		sz = code ? kcode_charsize_s(buf) : kcode_charsize_e(buf);
	}
	
	return(newSVpv((unsigned char*) newbuf0, c));
}

/*-------------------------------------------------------------------*/

MODULE = Kcode PACKAGE = Kcode

SV*
replaceS(str, hash, maxlen=0)
	unsigned char* str
	SV*   hash
	int   maxlen
	CODE:
	RETVAL = kc_replace(str, hash, maxlen, 1);
	OUTPUT:
	RETVAL

SV*
replaceE(str, hash, maxlen=0)
	unsigned char* str
	SV*   hash
	int   maxlen
	CODE:
	RETVAL = kc_replace(str, hash, maxlen, 0);
	OUTPUT:
	RETVAL

int
charsizeS(str)
	unsigned char* str
	CODE:
	RETVAL = kcode_charsize_s(str);
	OUTPUT:
	RETVAL

int
charsizeE(str)
	unsigned char* str
	CODE:
	RETVAL = kcode_charsize_e(str);
	OUTPUT:
	RETVAL

SV*
s2e(str)
	unsigned char* str
	CODE:
	char* p = kcode_s2e(NULL, str);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

SV*
e2s(str)
	unsigned char* str
	CODE:
	char* p = kcode_e2s(NULL, str);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

SV*
j2e(str)
	unsigned char* str
	CODE:
	char* p = kcode_j2e(NULL, str);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

SV*
e2j(str)
	unsigned char* str
	CODE:
	char* p = kcode_e2j(NULL, str);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

SV*
j2s(str)
	unsigned char* str
	CODE:
	char* p = kcode_j2s(NULL, str);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

SV*
s2j(str, emoji=0)
	unsigned char* str
	int emoji
	CODE:
	char* p = kcode_s2j(NULL, str, emoji);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

SV*
h2z(str, emoji=0)
	unsigned char* str
	int emoji
	CODE:
	char* p = kcode_h2z(NULL, str, emoji);
	RETVAL = newSVpv(p, 0);
	free(p);
	OUTPUT:
	RETVAL

