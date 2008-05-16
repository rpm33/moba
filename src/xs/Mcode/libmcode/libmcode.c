#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include "libmcode.h"

//--------------------------------------

void* mcode_openMap(char* file) {
	void* pDat;
	int len;
	FILE* fd;
	
	fd = fopen(file, "rb");
	if (fd == NULL) return(NULL);
	fseek(fd, 0, SEEK_END);
	len = ftell(fd);
	fseek(fd, 0, SEEK_SET);
	if (len < 4) {
		fclose(fd);
		return(NULL);
	}
	pDat = mmap(0, len, PROT_READ, MAP_SHARED, fileno(fd), 0);
	fclose(fd);
	
	if (*((int*)(pDat)) != len) {
		munmap(pDat, len);
		return(NULL);
	}
	return(pDat);
}

//--------------------------------------

void mcode_closeMap(void* pDat) {
	munmap(pDat, *((int*)(pDat)));
}

//====================================================================
//                     全キャリア -> 内部形式
//====================================================================

// 実質的には、softbank の sjis 絵文字を
// 一律３バイトになるよう変換しているだけ

void mcode_any2u(uchar* pDst, uchar* pSrc, int maxlen) {
	uchar  *pSrcE, *pDstE, c1, *pConv;
	int    sz, mode;
	
	c1    = 0;
	sz    = 0;
	pSrcE = pSrc + strlen(pSrc);
	pDstE = pDst + maxlen;
	
	mode  = 0; // 絵文字モードではない
	while (pSrc < pSrcE) {
		
		//--------------------
		// 文字単位を取得
		
		if (mode == 1) {
			
			// 絵文字終端チェック
			
			if (*pSrc == 0x0f) {
				mode = 0;
				pSrc++;
				continue;
			}
		} else {
			sz = _mcode_charsize(pSrc);
			
			if (sz == MC_CHAR_DOCOMO)   sz = 2;
			if (sz == MC_CHAR_EZWEB)    sz = 2;
			if (sz == MC_CHAR_VODAFONE) sz = 3;
			if (sz == MC_CHAR_HANKANA)  sz = 1;
			
			// 不正文字と VODAFONE 絵文字の処理
			
			if (sz < 0) {
				if (sz == -2) {
					if (pDstE - pDst < 2) break;
					*pDst = MC_NA1; pDst++;
					*pDst = MC_NA2; pDst++;
				}
				pSrc += (-sz);
				continue;
			}
			if (sz >= 5) {
				mode = 1;
				pSrc += 2;
				c1 = 0;
				continue;
			}
		}
		
		//--------------------
		// 変換・書き込み
		
		if (mode == 1) {
			if (c1) {
				if (pDstE - pDst < 3) break;
				*pDst = 0x0B;  pDst++;
				*pDst = c1;    pDst++;
				*pDst = *pSrc; pDst++; pSrc++;
			} else {
				c1 = *pSrc; pSrc++;
				continue;
			}
		} else {
			if (sz == 2) {
				if (pDstE - pDst < 2) break;
				*pDst = *pSrc; pSrc++; pDst++;
				if (pSrc == pSrcE) break;
				*pDst = *pSrc; pSrc++; pDst++;
			} else {
				if (pDstE - pDst < 1) break;
				*pDst = *pSrc; pSrc++; pDst++;
			}
		}
	}
	*pDst = '\0';
}

//====================================================================
//                     内部形式 -> 各キャリア
//====================================================================

int mcode_u2any(uchar* pDst, uchar* pSrc, int maxlen, void* pDat) {
	uchar  *pSrcE, *pDstE, *pConv, *pConvSrc, c1, c2;
	ushort *pMap;
	int    sz, c ,i;
	
	pMap  = (ushort*) (pDat + MC_MAPFILE_OFS_MAP);
	pConv = (uchar*)  (pDat + MC_MAPFILE_OFS_STR);
	pSrcE = pSrc + strlen(pSrc);
	pDstE = pDst + maxlen;
	
	c1 = c2 = 0;
	if (!pDst) maxlen = 0;
	
	while (pSrc < pSrcE) {
		
		//--------------------
		// 文字単位を取得
		
		sz = _mcode_charsize(pSrc);
		
		switch (sz) {
		case MC_CHAR_DOCOMO:  sz = 2; break;
		case MC_CHAR_EZWEB:   sz = 2; break;
		case MC_CHAR_HANKANA: sz = 1; break;
		}
		
		//--------------------
		// 不正文字の処理
		
		if (sz < 0) {
			if (sz == -2) {
				if (pDst && pDstE - pDst < 2) break;
				if (pDst) {
					*pDst = MC_NA1; pDst++;
					*pDst = MC_NA2; pDst++;
				} else {
					maxlen += 2;
				}
			}
			pSrc += (-sz);
			if (pSrc >= pSrcE) break;
			continue;
		}
		
		//--------------------
		
		if (sz > 2 && sz != MC_CHAR_VODAFONE) {
			if (pDst && pDstE - pDst < sz) break;
			if (pDst) {
				for (i = 0; i < sz; i++) {
					*pDst = *pSrc; pDst++; pSrc++;
				}
			} else {
				pSrc   += sz;
				maxlen += sz;
			}
			
		} else {
			
			// 文字を取得
			
			if (sz == MC_CHAR_VODAFONE) {
				            pSrc++; if (pSrc == pSrcE) break;
				c1 = *pSrc; pSrc++; if (pSrc == pSrcE) break;
				c2 = *pSrc; pSrc++;
				c  = (c1 << 8) | c2;
			} else if (sz == 1) {
				c1 = *pSrc; pSrc++;
				c  = c1;
			} else {
				c1 = *pSrc; pSrc++; if (pSrc == pSrcE) break;
				c2 = *pSrc; pSrc++;
				c  = (c1 << 8) | c2;
			}
			
			if (pMap[c]) { // 変換対象がある場合
				
				pConvSrc = &(pConv[pMap[c]]);
				while (*pConvSrc) {
					if (pDst && pDstE - pDst < 1) break;
					if (pDst) {
						*pDst = *pConvSrc; pDst++;
					} else {
						maxlen ++;
					}
					pConvSrc++;
				}
			} else { // 変換対象がない場合
				
				if (sz == MC_CHAR_VODAFONE) {
					if (pDst && pDstE - pDst < 3) break;
					if (pDst) {
						*pDst = 0x0B; pDst++;
						*pDst = c1;   pDst++;
						*pDst = c2;   pDst++;
					} else {
						maxlen += 3;
					}
				} else if (sz == 2) {
					if (pDst && pDstE - pDst < 2) break;
					if (pDst) {
						*pDst = c1; pDst++;
						*pDst = c2; pDst++;
					} else {
						maxlen += 2;
					}
				} else if (sz == 1) {
					if (pDst && pDstE - pDst < 1) break;
					if (pDst) {
						*pDst = c1; pDst++;
					} else {
						maxlen ++;
					}
				}
			}
		}
	}
	
	if (pDst) {
		*pDst = '\0';
	} else {
		maxlen++;
	}
	
	return(maxlen);
}

//====================================================================
//                      絵文字対応 substr
//====================================================================

// maxlen: 最大バイト数

void mcode_usub(uchar* pDst, uchar* pSrc, int maxlen) {
	uchar  *pSrcE, *pDstE, c1, c2;
	int    sz, len, i;
	
	pSrcE = pSrc + strlen(pSrc);
	pDstE = pDst + maxlen;
	
	c1 = c2 = 0;
	
	while (pSrc < pSrcE) {
		
		// 文字単位を取得
		
		sz = _mcode_charsize(pSrc);
		
		if (sz == MC_CHAR_VODAFONE) sz = 3;
		if (sz == MC_CHAR_DOCOMO)   sz = 2;
		if (sz == MC_CHAR_EZWEB)    sz = 2;
		if (sz == MC_CHAR_HANKANA)  sz = 1;
		
		if (sz < 0) { // 不正文字の処理
			if (sz == -2) {
				if (pDstE - pDst < 2) break;
				*pDst = MC_NA1; pDst++;
				*pDst = MC_NA2; pDst++;
			}
			pSrc += (-sz);
			if (pSrc >= pSrcE) break;
			continue;
		}
		
		// ソース文字を取得
		
		if (pDstE - pDst < sz) break;
		for (i = 0; i < sz; i++) {
			*pDst = *pSrc; pSrc++; pDst++; if (pSrc == pSrcE) break;
		}
	}
	*pDst = '\0';
}

//====================================================================
//                          絵文字チェック
//====================================================================

int mcode_check_emoji(uchar* pSrc) {
	uchar  *pSrcE;
	int    sz;
	
	pSrcE = pSrc + strlen(pSrc);
	
	while (pSrc < pSrcE) {
		sz = _mcode_charsize(pSrc);
		if (sz == MC_CHAR_HANKANA) sz = 1;
		if (sz == MC_CHAR_DOCOMO   ||
			sz == MC_CHAR_EZWEB    ||
			sz == MC_CHAR_VODAFONE ||
			sz >= 5) return(1);
		if (sz > 0) {
			pSrc += sz;
		} else {
			pSrc -= sz;
		}
	}
	return(0);
}

//====================================================================
//                       文字サイズ（バイト数）
//====================================================================

int _mcode_charsize(const uchar* pChr) {
	uchar c, c2, c3;
	c  = *pChr;
	if (!c) return(0);
	c2 = pChr[1];
	
	// 漢字
	
	if (c >= 0x81 && c <= 0x9F ||
	    c >= 0xE0 && c <= 0xF2) {
		if (!c2) return(-1);
		if (c2 >= 0x40 && c2 <= 0x7E ||
		    c2 >= 0x80 && c2 <= 0xFC) {
			return(2);
		} else {
			return(-2);
		}
	}
	
	// 絵文字
	
	if (c >= 0xF8 && c <= 0xF9) {
		if (c2 >= 0x40 && c2 <= 0x7E ||
		    c2 >= 0x80 && c2 <= 0xFC) {
			return(MC_CHAR_DOCOMO);
		} else {
			return(-2);
		}
	}
	if (c >= 0xF3 && c <= 0xF7) {
		if (c2 >= 0x40 && c2 <= 0x7E ||
		    c2 >= 0x80 && c2 <= 0xFC) {
			return(MC_CHAR_EZWEB);
		} else {
			return(-2);
		}
	}
	if (c == 0x0B) { // 内部形式に変換後の vodafone
		if (!c2) return(-1);
		c3 = pChr[2];
		if (!c3) return(-2);
		if (0x20 <= c2 && c2 <= 0x7E &&
		    0x20 <= c3 && c3 <= 0x7E) {
			return(MC_CHAR_VODAFONE);
		} else {
			return(-3);
		}
	}
	if (c == 0x1B) { // 通常 vodafone
		int len = 1;
		int bad = 0;
		pChr++;
		while (*pChr) {
			if (len == 1) {
				if (*pChr != 0x24) bad = 1;
			} else if (*pChr == 0x0F) {
			} else if (*pChr < 0x20 || 0x7e < *pChr) {
				bad = 1;
			}
			len++;
			if (*pChr == 0x0F) break;
			pChr++;
		}
		if (len < 5 || len >= 10000) bad = 1;
		return(bad ? -len : len);
	}
	
	if (c >= 0x20 && c <= 0x7E) return(1);               // 通常ASCII
	if (c >= 0xA1 && c <= 0xDF) return(MC_CHAR_HANKANA); // 半角カナ
	
	// HT(0x09) LF(0x0A) CR(0x0D) VT(0x0B) 
	// 以外の制御文字は除去する
	// なお、SB は 1B 24 ** ** 0F
	
	return
		(c == 0x09 || c == 0x0A || c == 0x0B || c == 0x0D) ? 1 : -1;
}
