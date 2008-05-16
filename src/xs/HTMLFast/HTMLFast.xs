#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <stdio.h>
#include <string.h>

/*--------------------------------------------------------------------

split は１文字デリミタなら perl ネイティブの方が速い

--------------------------------------------------------------------*/

SV* htmlfast_decode      (SV* in, unsigned char* meta);
SV* htmlfast_encode      (SV* in, unsigned char* meta);
SV* htmlfast_specialchars(SV* in, int f_nl2br);
SV* htmlfast_token       (SV* in, unsigned char* delim); // 遅いので使わない

//----------------------------------------------------------

SV* htmlfast_decode(SV* in, unsigned char* meta) {
	unsigned char *pi, *po, *out, *tail, c, d, esc;
	int len;
	SV* sv;
	
	if (!SvOK(in)) return(newSVpv("", 0));
	
	esc  = *meta;
	pi   = SvPV(in, len);
	if (!len) return(newSVpv("", 0));
	New(0, out, len + 1, char);
	po = out;
	tail = pi + len - 1;
	
	while (pi <= tail) {
		c = *pi; pi++;
		if (c == esc || !esc) {
			c  = *pi; pi++; if (!c) break;
			d  = ((c < 0x3a) ? (c - 0x30) : ((c | 0x20) - 0x57)) << 4;
			c  = *pi; pi++; if (!c) break;
			d |= ((c < 0x3a) ? (c - 0x30) : ((c | 0x20) - 0x57));
			*po = d; po++;
		} else if (c == '+') {
			*po = ' '; po++;
		} else {
			*po = c; po++;
		}
	}
	
	sv = newSVpv(out, po - out);
	Safefree(out);
	return(sv);
}

//----------------------------------------------------------

SV* htmlfast_encode(SV* in, unsigned char* meta) {
	unsigned char *pi, *po, *out, *tail, c, d, esc;
	int len;
	SV* sv;
	
	if (!SvOK(in)) return(newSVpv("", 0));
	
	esc  = *meta;
	pi   = SvPV(in, len);
	if (!len) return(newSVpv("", 0));
	New(0, out, len * 3 + 1, char);
	po = out;
	tail = pi + len - 1;
	
	while (pi <= tail) {
		c = *pi; pi++;
		if (esc && (
		    c >= '0' && c <= '9' ||
		    c >= 'a' && c <= 'z' ||
		    c >= 'A' && c <= 'Z')) {
			*po = c; po++;
		} else {
			*po = esc; po++;
			*po = (c         >= 0xa0) ?
				((c >>   4) + 'A'-10) : ((c >>   4) | '0'); po++;
			*po = ((c & 0x0f) >= 0x0a) ?
				((c & 0x0f) + 'A'-10) : ((c & 0x0f) | '0'); po++;
		}
	}
	
	sv = newSVpv(out, po - out);
	Safefree(out);
	return(sv);
}

//----------------------------------------------------------

SV* htmlfast_specialchars(SV* in, int f_nl2br) {
	unsigned char *pi, *pi0, *po, *out, *tail, c;
	int len, len2;
	SV* sv;
	
	if (!SvOK(in)) return(newSVpv("", 0));
	
	pi0 = pi = SvPV(in, len);
	if (!len) return(newSVpv("", 0));
	tail = pi + len - 1;
	
	len2 = len;
	while (pi <= tail) {
		switch (*pi) {
		case '>'  : len2 += 3; break;
		case '<'  : len2 += 3; break;
		case '&'  : len2 += 4; break;
		case '"'  : len2 += 5; break;
		case '\n' : if (f_nl2br) len2 += 5; break;
		}
		pi++;
	}
	if (len == len2) return(newSVsv(in));
	
	New(0, out, len2 + 1, char);
	po = out;
	
	pi = pi0;
	while (pi <= tail) {
		c = *pi; pi++;
		switch (c) {
		case '>'  :
			*po = '&'; po++; *po = 'g'; po++;
			*po = 't'; po++; *po = ';'; po++;
			break;
		case '<'  :
			*po = '&'; po++; *po = 'l'; po++;
			*po = 't'; po++; *po = ';'; po++;
			break;
		case '&'  :
			*po = '&'; po++; *po = 'a'; po++;
			*po = 'm'; po++; *po = 'p'; po++;
			*po = ';'; po++;
			break;
		case '"'  :
			*po = '&'; po++; *po = 'q'; po++;
			*po = 'u'; po++; *po = 'o'; po++;
			*po = 't'; po++; *po = ';'; po++;
			break;
		case '\n' :
			if (f_nl2br) {
				*po = '<'; po++; *po = 'b'; po++;
				*po = 'r'; po++; *po = ' '; po++;
				*po = '/'; po++; *po = '>'; po++;
			} else {
				*po = c; po++;
			}
			break;
		default: *po = c; po++;
		}
	}
	
	sv = newSVpv(out, po - out);
	Safefree(out);
	return(sv);
}

//----------------------------------------------------------

SV* htmlfast_token(SV* in, unsigned char* delim) {
	char *pi0, *pi, *tail, c, d;
	int len;
	AV* av;
	
	if (!SvPOK(in)) return(newRV_noinc((SV*) newAV()));
	
	d = *delim;
	pi0 = pi = SvPV(in, len);
	tail = pi + len - 1;
	av = newAV();
	
	while (pi <= tail) {
		if (*pi == d) {
			av_push(av, newSVpvn(pi0, pi - pi0));
			pi0 = pi + 1;
		}
		pi++;
	}
	if (pi > pi0) {
		av_push(av, newSVpvn(pi0, pi - pi0));
	}
	
	return(newRV_noinc((SV*) av));
}

/*-------------------------------------------------------------------*/

MODULE = HTMLFast PACKAGE = HTMLFast

SV*
decode(in, meta="%")
	SV* in
	char* meta
	CODE:
	RETVAL = htmlfast_decode(in, meta);
	OUTPUT:
	RETVAL

SV*
encode(in, meta="%")
	SV* in
	char* meta
	CODE:
	RETVAL = htmlfast_encode(in, meta);
	OUTPUT:
	RETVAL

SV*
htmlspecialchars(in, f_nl2br=0)
	SV* in
	int f_nl2br
	CODE:
	RETVAL = htmlfast_specialchars(in, f_nl2br);
	OUTPUT:
	RETVAL
