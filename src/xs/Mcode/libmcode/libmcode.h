#ifndef __LIBMCODE_H
#define __LIBMCODE_H

#ifndef uint
#define uint unsigned int
#endif
#ifndef ushort
#define ushort unsigned short
#endif
#ifndef uchar
#define uchar unsigned char
#endif

#define MC_MAPFILE_OFS_MAP 4
#define MC_MAPFILE_OFS_STR 0x20004

#define MC_CHAR_DOCOMO   10000
#define MC_CHAR_EZWEB    10001
#define MC_CHAR_VODAFONE 10002
#define MC_CHAR_HANKANA  11000

#define MC_NA1 0x81
#define MC_NA2 0xAC

void* mcode_openMap(char* file);
void  mcode_closeMap(void* pMap);

void mcode_any2u(uchar* pDst, uchar* pSrc, int maxlen);
int  mcode_u2any(uchar* pDst, uchar* pSrc, int maxlen, void* pMap);
void mcode_usub (uchar* pDst, uchar* pSrc, int maxlen);
int  mcode_check_emoji(uchar* pSrc);
int _mcode_charsize(const unsigned char* pChr);

#endif
