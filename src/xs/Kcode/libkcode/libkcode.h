#ifndef __LIBKCODE_H
#define __LIBKCODE_H

char* kcode_j2s(unsigned char* dst, const unsigned char* src);
char* kcode_s2j(unsigned char* dst, const unsigned char* src, const int emoji);
char* kcode_e2j(unsigned char* dst, const unsigned char* src);
char* kcode_j2e(unsigned char* dst, const unsigned char* src);
char* kcode_e2s(unsigned char* dst, const unsigned char* src);
char* kcode_s2e(unsigned char* dst, const unsigned char* src);
char* kcode_h2z(unsigned char* dst, const unsigned char* src, const int emoji);
int   kcode_get_jtype(const unsigned char** pSrc);
int   kcode_charsize_s(const unsigned char* ptr);
int   kcode_charsize_e(const unsigned char* ptr);
void  _h2z(unsigned char c,
	unsigned char **ppDst, const unsigned char **ppSrc, int *pLen);

#endif
