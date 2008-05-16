#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include "libmcode.h"

#ifndef uint
#define uint unsigned int
#endif
#ifndef ushort
#define ushort unsigned short
#endif
#ifndef uchar
#define uchar unsigned char
#endif

#define _rviv(rv) SvIV((SV*)SvRV(rv))

//--------------------------------------------------------------------

SV*  pf_mcode_openMap (char* file);
void pf_mcode_closeMap(void* pDat);

SV*  pf_mcode_any2u(            char* str, int maxlen);
SV*  pf_mcode_u2any(void* pDat, char* str, int maxlen);
SV*  pf_mcode_usub (char* str, int maxlen);

//--------------------------------------------------------------------

SV* pf_mcode_openMap(char* file) {
	void* pDat = mcode_openMap(file);
	if (pDat) return(newRV_noinc(newSViv((int) pDat)));
	return(&PL_sv_undef);
}

//--------------------------------------------------------------------

void pf_mcode_closeMap(void* pDat) {
	if (pDat) {
		mcode_closeMap(pDat);
	}
}

//--------------------------------------------------------------------

SV* pf_mcode_any2u(char* str, int maxlen) {
	char* buf;
	SV* sv;
	
	if (!maxlen) maxlen = strlen(str) * 3;
	buf = (char*) malloc(maxlen + 1);
	if (!buf) return(&PL_sv_undef);
	mcode_any2u(buf, str, maxlen);
	sv = newSVpv(buf, 0);
	free(buf);
	return(sv);
}

//--------------------------------------------------------------------

SV* pf_mcode_u2any(void* pDat, char* str, int maxlen) {
	char* buf;
	SV* sv;
	
	if (!maxlen) maxlen = mcode_u2any(NULL, str, 0, pDat);
	buf = (char*) malloc(maxlen + 1);
	if (!buf) return(&PL_sv_undef);
	mcode_u2any(buf, str, maxlen, pDat);
	sv = newSVpv(buf, 0);
	free(buf);
	return(sv);
}

//--------------------------------------------------------------------

SV* pf_mcode_usub(char* str, int maxlen) {
	char* buf;
	SV* sv;
	
	buf = (char*) malloc(maxlen + 1);
	if (!buf) return(&PL_sv_undef);
	mcode_usub(buf, str, maxlen);
	sv = newSVpv(buf, 0);
	free(buf);
	return(sv);
}


//--------------------------------------------------------------------

MODULE = Mcode PACKAGE = Mcode

SV*
openMap(file)
	char* file
	CODE:
	RETVAL = pf_mcode_openMap(file);
	OUTPUT:
	RETVAL

void
closeMap(rObj)
	SV* rObj
	CODE:
	pf_mcode_closeMap((void*) _rviv(rObj));

SV*
any2u(rObj, str, maxlen=0)
	SV* rObj
	unsigned char* str
	int maxlen
	CODE:
	RETVAL = pf_mcode_any2u(str, maxlen);
	OUTPUT:
	RETVAL

SV*
_u2any(rObj, str, maxlen=0)
	SV* rObj
	unsigned char* str
	int maxlen
	CODE:
	RETVAL = pf_mcode_u2any((void*) _rviv(rObj), str, maxlen);
	OUTPUT:
	RETVAL

SV*
usub(rObj, str, maxlen)
	SV* rObj
	unsigned char* str
	int maxlen
	CODE:
	RETVAL = pf_mcode_usub(str, maxlen);
	OUTPUT:
	RETVAL

int
checkEmoji(rObj, str)
	SV* rObj
	unsigned char* str
	CODE:
	RETVAL = mcode_check_emoji(str);
	OUTPUT:
	RETVAL
