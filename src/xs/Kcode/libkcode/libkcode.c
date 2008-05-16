#include "libkcode.h"
#include <stdlib.h>

#define KC_UNKNOWN 0
#define KC_ASCII   1
#define KC_JIS0208 2
#define KC_JIS0212 3
#define KC_HANKANA 4

#define _kcode_JIS0208(mode,dst,len) \
	if ((mode) != KC_JIS0208) { \
		if ((dst)) { \
			*(dst) = 0x1B; (dst)++; \
			*(dst) = '$';  (dst)++; \
			*(dst) = 'B';  (dst)++; \
		} else { (len) += 3; } \
		(mode) = KC_JIS0208; \
	}
	
#define _kcode_ASCII(mode,dst,len) \
	if ((mode) != KC_ASCII) { \
		if ((dst)) { \
			*(dst) = 0x1B; (dst)++; \
			*(dst) = '(';  (dst)++; \
			*(dst) = 'B';  (dst)++; \
		} else { (len) += 3; } \
		(mode) = KC_ASCII; \
	}
	
#define _kcode_HANKANA(mode,dst,len) \
	if ((mode) != KC_HANKANA) { \
		if ((dst)) { \
			*(dst) = 0x1B; (dst)++; \
			*(dst) = '(';  (dst)++; \
			*(dst) = 'I';  (dst)++; \
		} else { (len) += 3; } \
		(mode) = KC_HANKANA; \
	}
	
#define _kcode_JIS0212(mode,dst,len) \
	if ((mode) != KC_JIS0212) { \
		if ((dst)) { \
			*(dst) = 0x1B; (dst)++; \
			*(dst) = '$';  (dst)++; \
			*(dst) = '(';  (dst)++; \
			*(dst) = 'D';  (dst)++; \
		} else { (len) += 4; } \
		(mode) = KC_JIS0212; \
	}

#define _kc_is_safe_ascii(c) \
	(((c) >= 0x20 && (c) <= 0x7E) || \
	(c) == 0x09 || (c) == 0x0A || (c) == 0x0D)

//------------------------------------------------ JIS -> EUC

char* kcode_j2e(unsigned char* dst, const unsigned char* src) {
	const unsigned char *src0;
	      unsigned char *dst0, c1, c2;
	int len = 0;
	int mode = KC_ASCII;
	
	dst0 = dst;
	src0 = src;
	
	while (c1 = *src) {
		src++;
		if (c1 & 0x80) continue;
		
		// モード切替
		
		if (c1 == 0x1B) {
			mode = kcode_get_jtype(&src);
			continue;
		}
		
		// 文字コピー
		
		switch(mode) {
		case KC_ASCII:
			if (_kc_is_safe_ascii(c1)) {
				if (dst) {
					*dst = c1; dst++;
				} else { len ++; }
			}
			break;
		case KC_JIS0208:
			if (c1 >= 0x21 && c1 <= 0x7E) {
				if (c2 = *src) src++;
				if (c2 >= 0x21 && c2 <= 0x7E) {
					c1 |= 0x80;
					c2 |= 0x80;
					if (dst) {
						*dst = c1; dst++;
						*dst = c2; dst++;
					} else { len += 2; }
				}
			} else if (_kc_is_safe_ascii(c1)) {
				if (dst) {
					*dst = c1; dst++;
				} else { len ++; }
			}
			break;
		case KC_JIS0212:
			if (c1 >= 0x21 && c1 <= 0x7E) {
				if (!*src) break;
				if (c2 = *src) src++;
				if (c2 >= 0x21 && c2 <= 0x7E) {
					if (dst) {
						*dst = 0x8F;      dst++;
						*dst = c1 | 0x80; dst++;
						*dst = c2 | 0x80; dst++;
					} else { len += 3; }
				}
			} else if (_kc_is_safe_ascii(c1)) {
				if (dst) {
					*dst = c1; dst++;
				} else { len ++; }
			}
			break;
		case KC_HANKANA:
			if (c1 >= 0x21 && c1 <= 0x6F) {
				if (dst) {
					*dst = 0x8E;      dst++;
					*dst = c1 | 0x80; dst++;
				} else { len += 2; }
			} else if (_kc_is_safe_ascii(c1)) {
				if (dst) {
					*dst = c1; dst++;
				} else { len ++; }
			}
			break;
		case KC_UNKNOWN: break;
		}
	}
	if (dst) {
		*dst = '\0';
	} else { len ++; }
	
	if (!dst) {
		dst0 = (unsigned char*) malloc(len);
		if (dst0) kcode_j2e(dst0, src0);
	}
	return(dst0);
}

//------------------------------------------------ JIS -> SJIS

char* kcode_j2s(unsigned char* dst, const unsigned char* src) {
	unsigned char *dst0, c1, c2;
	int mode = KC_ASCII;
	
	if (!dst) {
		const unsigned char *s = src;
		int l = 0;
		while (*s) { s++; l++; }
		dst = (unsigned char*) malloc(l + 1);
	}
	dst0 = dst;
	
	while (c1 = *src) {
		src++;
		if (c1 & 0x80) continue;
		
		// モード切替
		
		if (c1 == 0x1B) {
			mode = kcode_get_jtype(&src);
			continue;
		}
		
		// 文字コピー
		
		switch(mode) {
		case KC_ASCII:
			if (_kc_is_safe_ascii(c1)) {
				*dst = c1; dst++;
			}
			break;
		case KC_JIS0208:
			if (c1 >= 0x21 && c1 <= 0x7E) {
				if (c2 = *src) src++;
				if (c2 >= 0x21 && c2 <= 0x7E) {
					c1 |= 0x80;
					c2 |= 0x80;
					if (c1 & 1) {
						c1 = (c1 >> 1) + (c1 < 0xDF ? 0x31 : 0x71);
						c2 = c2 - 0x60 - (c2 < 0xE0 ? 1 : 0);
					} else {
						c1 = (c1 >> 1) + (c1 < 0xDF ? 0x30 : 0x70);
						c2 = c2 - 2;
					}
					*dst = c1; dst++;
					*dst = c2; dst++;
				}
			} else if (_kc_is_safe_ascii(c1)) {
				*dst = c1; dst++;
			}
			break;
		case KC_JIS0212:
			if (c1 >= 0x21 && c1 <= 0x7E) {
				if (c2 = *src) src++;
				if (c2 >= 0x21 && c2 <= 0x7E) {
					*dst = ' '; dst++;
					*dst = ' '; dst++;
				}
			} else if (_kc_is_safe_ascii(c1)) {
				*dst = c1; dst++;
			}
			break;
		case KC_HANKANA:
			if (c1 >= 0x21 && c1 <= 0x6F) {
				*dst = c1 | 0x80; dst++;
			} else if (_kc_is_safe_ascii(c1)) {
				*dst = c1; dst++;
			}
			break;
		case KC_UNKNOWN: break;
		}
	}
	*dst = '\0';
	return(dst0);
}

//------------------------------------------------ EUC -> JIS

char* kcode_e2j(unsigned char* dst, const unsigned char* src) {
	const unsigned char *src0;
	      unsigned char *dst0, c1, c2;
	int mode = KC_ASCII;
	int len = 0;
	
	dst0 = dst;
	src0 = src;
	
	while (c1 = *src) {
		src++;
		if (c1 == 0x8E) {
			if (c2 = *src) src++;
			if (c2 >= 0xA1 && c2 <= 0xDF) {
				_kcode_HANKANA(mode,dst,len);
				if (dst) {
					*dst = c2 & 0x7F; dst++;
				} else { len ++; }
			}
		} else if (c1 == 0x8F) {
			if (c1 = *src) src++;
			if (c1 >= 0xA1 && c1 <= 0xFE) {
				if (c2 = *src) src++;
				if (c2 <= 0xA1 && c2 <= 0xFE) {
					_kcode_JIS0212(mode,dst,len);
					if (dst) {
						*dst = c1 & 0x7F; dst++;
						*dst = c2 & 0x7F; dst++;
					} else { len += 2; }
				}
			}
		} else if (c1 >= 0xA1 && c1 <= 0xFE) {
			if (c2 = *src) src++;
			if (c2 >= 0xA1 && c2 <= 0xFE) {
				_kcode_JIS0208(mode,dst,len);
				if (dst) {
					*dst = c1 & 0x7F; dst++;
					*dst = c2 & 0x7F; dst++;
				} else { len += 2; }
			}
		} else if (_kc_is_safe_ascii(c1)) {
			_kcode_ASCII(mode,dst,len);
			if (dst) {
				*dst = c1; dst++;
			} else { len ++; }
		} else {
			int mode_old = mode;
			_kcode_ASCII(mode,dst,len);
			if (c1 >= 0x80) {
				if (*src) src++;
				if (dst) { *dst = ' '; dst++; } else { len ++; }
			}
			if (dst) { *dst = ' '; dst++; } else { len ++; }
			mode = mode_old;
			_kcode_ASCII(mode,dst,len);
		}
	}
	
	_kcode_ASCII(mode,dst,len)
	if (dst) { *dst = '\0'; } else { len ++; }
	
	if (!dst) {
		dst0 = (unsigned char*) malloc(len);
		if (dst0) kcode_e2j(dst0, src0);
	}
	return(dst0);
}

//------------------------------------------------ SJIS -> JIS

char* kcode_s2j(unsigned char* dst, const unsigned char* src, const int emoji) {
	const unsigned char *src0;
	      unsigned char *dst0, c1, c2;
	int len = 0;
	int mode = KC_ASCII;
	
	dst0 = dst;
	src0 = src;
	
	while (c1 = *src) {
		src++;
		if (c1 >= 0xA1 && c1 <= 0xDF) {
			_kcode_HANKANA(mode,dst,len);
			if (dst) {
				*dst = c1 & 0x7F; dst++;
			} else { len ++; }
		} else if (c1 >= 0x81 && c1 <= 0x9F ||
		           c1 >= 0xE0 && c1 <= 0xEF) {
			if (c2 = *src) src++;
			if (c2 >= 0x40 && c2 <= 0x7E ||
			    c2 >= 0x80 && c2 <= 0x9E) {
				c1 = (c1 << 1) - (c1 >= 0xE0 ? 0xE1 : 0x61);
				c2 += 0x60 + (c2 < 0x7F ? 1 : 0);
			} else if (c2 >= 0x9F && c2 <= 0xFC) {
				c1 = (c1 << 1) - (c1 >= 0xE0 ? 0xE0 : 0x60);
				c2 += 2;
			}
			if (c2 >= 0xA1 && c2 <= 0xFE) {
				_kcode_JIS0208(mode,dst,len);
				if (dst) {
					*dst = c1 & 0x7F; dst++;
					*dst = c2 & 0x7F; dst++;
				} else { len += 2; }
			}
		} else if (c1 >= 0xF0 && c1 <= 0xF9 && emoji==1) { // DoCoMo 絵文字対応
			if (c2 = *src) src++;
			if (c2 >= 0x40 && c2 <= 0x7E ||
			    c2 >= 0x80 && c2 <= 0x9E) {
				c1 = (c1 << 1) - 0x161;
				c2 += 0x60 + (c2 < 0x7F ? 1 : 0);
			} else if (c2 >= 0x9F && c2 <= 0xFC) {
				c1 = (c1 << 1) - 0x160;
				c2 += 2;
			}
			if (c2 >= 0xA1 && c2 <= 0xFE) {
				_kcode_JIS0208(mode,dst,len);
				if (dst) {
					*dst = c1;        dst++;
					*dst = c2 & 0x7F; dst++;
				} else { len += 2; }
			}
		} else if (_kc_is_safe_ascii(c1)) {
			_kcode_ASCII(mode,dst,len);
			if (dst) {
				*dst = c1; dst++;
			} else { len ++; }
		} else {
			_kcode_JIS0208(mode,dst,len);
			if (c1 == 0x0B) { // Vodafone Univ 割り当て
				if (*src) src+=2;
			} else if (c1 >= 0x80) {
				if (*src) src++;
			}
			if (dst) {
				*dst = 0x22; dst++;
				*dst = 0x2E; dst++;
			} else {
				len += 2;
			}
		}
	}
	
	_kcode_ASCII(mode,dst,len);
	if (dst) { *dst = '\0'; } else { len ++; }
	
	if (!dst) {
		dst0 = (unsigned char*) malloc(len);
		if (dst0) kcode_s2j(dst0, src0, emoji);
	}
	return(dst0);
}

//------------------------------------------------ SJIS -> EUC

char* kcode_s2e(unsigned char* dst, const unsigned char* src) {
	const unsigned char *src0;
	      unsigned char *dst0, c1, c2;
	int len = 0;
	
	dst0 = dst;
	src0 = src;
	
	while (c1 = *src) {
		src++;
		if (c1 >= 0x81 && c1 <= 0x9F ||
		    c1 >= 0xE0 && c1 <= 0xEF) {
			if (c2 = *src) src++;
			if (c2 >= 0x40 && c2 <= 0x7E ||
			    c2 >= 0x80 && c2 <= 0x9E) {
				if (dst) {
					*dst = (c1 << 1) - (c1 >= 0xE0 ? 0xE1 : 0x61); dst++;
					*dst = c2 + 0x60 + (c2 < 0x7F ? 1 : 0);        dst++;
				} else { len += 2; }
			} else if (c2 >= 0x9F && c2 <= 0xFC) {
				if (dst) {
					*dst = (c1 << 1) - (c1 >= 0xE0 ? 0xE0 : 0x60); dst++;
					*dst = c2 + 2;                                 dst++;
				} else { len += 2; }
			}
		} else if (c1 >= 0xA1 && c1 <= 0xDF) {
			if (dst) {
				*dst = 0x8E; dst++;
				*dst = c1;   dst++;
			} else { len += 2; }
		} else if (_kc_is_safe_ascii(c1)) {
			if (dst) {
				*dst = c1; dst++;
			} else { len ++; }
		} else if (c1 >= 0x80) {
			if (dst) {
				*dst = ' '; dst++; *dst = ' '; dst++;
			} else len += 2;
			if (*src) src++;
		} else {
			if (dst) { *dst = ' '; dst++; } else { len ++; }
		}
	}
	if (dst) {
		*dst = '\0';
	} else { len ++; }
	
	if (!dst) {
		dst0 = (unsigned char*) malloc(len);
		if (dst0) kcode_s2e(dst0, src0);
	}
	return(dst0);
}

//------------------------------------------------ EUC -> SJIS

char* kcode_e2s(unsigned char* dst, const unsigned char* src) {
	unsigned char *dst0, c1, c2;
	
	if (!dst) {
		const unsigned char *s = src;
		int l = 0;
		while (*s) { s++; l++; }
		dst = (unsigned char*) malloc(l + 1);
	}
	dst0 = dst;
	
	while (c1 = *src) {
		src++;
		if (c1 >= 0xA1 && c1 <= 0xFE) {
			if (c2 = *src) src++;
			if (c2 >= 0xA1 && c2 <= 0xFE) {
				if (c1 & 1) {
					*dst = (c1 >> 1) + (c1 < 0xDF ? 0x31 : 0x71); dst++;
					*dst = c2 - 0x60 - (c2 < 0xE0 ? 1 : 0); dst++;
				} else {
					*dst = (c1 >> 1) + (c1 < 0xDF ? 0x30 : 0x70); dst++;
					*dst = c2 - 2; dst++;
				}
			}
		} else if (c1 == 0x8E) {
			if (c2 = *src) src++;
			if (c2 >= 0xA1 && c2 <= 0xDF ||
			    c2 >= 0x80 && c2 <= 0x9E) {
				*dst = c2; dst++;
			}
		} else if (c1 == 0x8F) {
			if (c1 = *src) src++;
			if (c1 >= 0xA1 && c1 <= 0xFE) {
				if (c2 = *src) src++;
				if (c2 >= 0xA1 && c2 <= 0xFE) {
					*dst = ' '; dst++;
					*dst = ' '; dst++;
				}
			}
		} else if (_kc_is_safe_ascii(c1)) {
			*dst = c1; dst++;
		} else if (c1 >= 0x80) {
			*dst = ' '; dst++; *dst = ' '; dst++;
			if (*src) src++;
		} else {
			*dst = ' '; dst++;
		}
	}
	*dst = '\0';
	return(dst0);
}

//------------------------------------------------ 半角 -> 全角 (SJIS)

char* kcode_h2z(unsigned char* dst, const unsigned char* src, const int emoji) {
	const unsigned char *src0;
	      unsigned char *dst0, c1, c2, c3;
	int len = 0;
	
	dst0 = dst;
	src0 = src;
	
	while (c1 = *src) {
		src++;
		if (c1 >= 0x81 && c1 <= 0x9F ||
		    c1 >= 0xE0 && c1 <= 0xEF) {
			if (c2 = *src) src++;
			if (c2 >= 0x40 && c2 <= 0x7E ||
			    c2 >= 0x80 && c2 <= 0xFC) {
				if (dst) {
					*dst = c1; dst++; *dst = c2; dst++;
				} else { len += 2; }
			}
		} else if (c1 >= 0xA1 && c1 <= 0xDF) { // 半角カナ
			_h2z(c1, &dst, &src, &len);
		} else if (_kc_is_safe_ascii(c1)) {
			if (dst) {
				*dst = c1; dst++;
			} else { len ++; }
		} else if (c1 == 0x0B) { // 0B XX XX:Vodafone Univ
			if (c2 = *src) src++;
			if (c3 = *src) src++;
			if (emoji) {
				if (dst) {
					*dst = c1; dst++; *dst = c2; dst++; *dst = c3; dst++;
				} else { len += 3; }
			} else {
				if (dst) {
					*dst = 0x81; dst++; *dst = 0xAC; dst++;
				} else { len += 2; }
			}
		} else if (c1 >= 0xF3 && c1 <= 0xF9) { // F3-F7:EZweb F8,F9:DoCoMo
			if (c2 = *src) src++;
			if (emoji) {
				if (dst) {
					*dst = c1; dst++; *dst = c2; dst++;
				} else { len += 2; }
			} else {
				if (dst) {
					*dst = 0x81; dst++; *dst = 0xAC; dst++;
				} else { len += 2; }
			}
		} else if (c1 >= 0x80) {
			if (*src) src++;
			if (dst) {
				*dst = 0x81; dst++; *dst = 0xAC; dst++;
			} else { len += 2; }
		} else {
			if (dst) { *dst = ' '; dst++; } else { len ++; }
		}
	}
	if (dst) {
		*dst = '\0';
	} else { len ++; }
	
	if (!dst) {
		dst0 = (unsigned char*) malloc(len);
		if (dst0) kcode_h2z(dst0, src0, emoji);
	}
	return(dst0);
}

// 0xA0:     ｡  ｢  ｣  ､  ･  ｦ  ｧ  ｨ  ｩ  ｪ  ｫ  ｬ  ｭ  ｮ  ｯ
// 0xB0:  ｰ  ｱ  ｲ  ｳ  ｴ  ｵ  ｶ  ｷ  ｸ  ｹ  ｺ  ｻ  ｼ  ｽ  ｾ  ｿ
// 0xC0:  ﾀ  ﾁ  ﾂ  ﾃ  ﾄ  ﾅ  ﾆ  ﾇ  ﾈ  ﾉ  ﾊ  ﾋ  ﾌ  ﾍ  ﾎ  ﾏ
// 0xD0:  ﾐ  ﾑ  ﾒ  ﾓ  ﾔ  ﾕ  ﾖ  ﾗ  ﾘ  ﾙ  ﾚ  ﾛ  ﾜ  ﾝ  ﾞ  ﾟ

void _h2z(c, ppDst, ppSrc, pLen)
unsigned char c;
unsigned char **ppDst;
const unsigned char **ppSrc;
int            *pLen;
{
	int z1 = 0; // 全角コード（通常）
	int z2 = 0; // 全角コード（濁点つき）
	int z3 = 0; // 全角コード（半濁点つき）
	
	switch (c) {
		case 0xa1: z1 = 0x8142; break;
		case 0xa2: z1 = 0x8175; break;
		case 0xa3: z1 = 0x8176; break;
		case 0xa4: z1 = 0x8141; break;
		case 0xa5: z1 = 0x8145; break;
		case 0xa6: z1 = 0x8392; break;
		case 0xa7: z1 = 0x8340; break;
		case 0xa8: z1 = 0x8342; break;
		case 0xa9: z1 = 0x8344; break;
		case 0xaa: z1 = 0x8346; break;
		case 0xab: z1 = 0x8348; break;
		case 0xac: z1 = 0x8383; break;
		case 0xad: z1 = 0x8385; break;
		case 0xae: z1 = 0x8387; break;
		case 0xaf: z1 = 0x8362; break;
		case 0xb0: z1 = 0x815b; break;
		case 0xb1: z1 = 0x8341; break;
		case 0xb2: z1 = 0x8343; break;
		case 0xb3: z1 = 0x8345; z2 = 0x8394; break;
		case 0xb4: z1 = 0x8347; break;
		case 0xb5: z1 = 0x8349; break;
		case 0xb6: z1 = 0x834a; z2 = 0x834b; break;
		case 0xb7: z1 = 0x834c; z2 = 0x834d; break;
		case 0xb8: z1 = 0x834e; z2 = 0x834f; break;
		case 0xb9: z1 = 0x8350; z2 = 0x8351; break;
		case 0xba: z1 = 0x8352; z2 = 0x8353; break;
		case 0xbb: z1 = 0x8354; z2 = 0x8355; break;
		case 0xbc: z1 = 0x8356; z2 = 0x8357; break;
		case 0xbd: z1 = 0x8358; z2 = 0x8359; break;
		case 0xbe: z1 = 0x835a; z2 = 0x835b; break;
		case 0xbf: z1 = 0x835c; z2 = 0x835d; break;
		case 0xc0: z1 = 0x835e; z2 = 0x835f; break;
		case 0xc1: z1 = 0x8360; z2 = 0x8361; break;
		case 0xc2: z1 = 0x8363; z2 = 0x8364; break;
		case 0xc3: z1 = 0x8365; z2 = 0x8366; break;
		case 0xc4: z1 = 0x8367; z2 = 0x8368; break;
		case 0xc5: z1 = 0x8369; break;
		case 0xc6: z1 = 0x836a; break;
		case 0xc7: z1 = 0x836b; break;
		case 0xc8: z1 = 0x836c; break;
		case 0xc9: z1 = 0x836d; break;
		case 0xca: z1 = 0x836e; z2 = 0x836f; z3 = 0x8370; break;
		case 0xcb: z1 = 0x8371; z2 = 0x8372; z3 = 0x8373; break;
		case 0xcc: z1 = 0x8374; z2 = 0x8375; z3 = 0x8376; break;
		case 0xcd: z1 = 0x8377; z2 = 0x8378; z3 = 0x8379; break;
		case 0xce: z1 = 0x837a; z2 = 0x837b; z3 = 0x837c; break;
		case 0xcf: z1 = 0x837d; break;
		case 0xd0: z1 = 0x837e; break;
		case 0xd1: z1 = 0x8380; break;
		case 0xd2: z1 = 0x8381; break;
		case 0xd3: z1 = 0x8382; break;
		case 0xd4: z1 = 0x8384; break;
		case 0xd5: z1 = 0x8386; break;
		case 0xd6: z1 = 0x8388; break;
		case 0xd7: z1 = 0x8389; break;
		case 0xd8: z1 = 0x838a; break;
		case 0xd9: z1 = 0x838b; break;
		case 0xda: z1 = 0x838c; break;
		case 0xdb: z1 = 0x838d; break;
		case 0xdc: z1 = 0x838f; break;
		case 0xdd: z1 = 0x8393; break;
		case 0xde: z1 = 0x814a; break;
		case 0xdf: z1 = 0x814b; break;
	}
	
	if (z2 && **ppSrc == 0xde) { // 濁点
		(*ppSrc)++;
		if (*ppDst) {
			**ppDst = z2 >> 8;   (*ppDst)++;
			**ppDst = z2 & 0xff; (*ppDst)++;
		} else { (*pLen) += 2; }
	} else if (z3 && **ppSrc == 0xdf) { // 半濁点
		(*ppSrc)++;
		if (*ppDst) {
			**ppDst = z3 >> 8;   (*ppDst)++;
			**ppDst = z3 & 0xff; (*ppDst)++;
		} else { (*pLen) += 2; }
	} else if (z1) { // 通常
		if (*ppDst) {
			**ppDst = z1 >> 8;   (*ppDst)++;
			**ppDst = z1 & 0xff; (*ppDst)++;
		} else { (*pLen) += 2; }
	}
}

//------------------------------------------------ JIS ESC 種別判別

int kcode_get_jtype(const unsigned char** pSrc) {
	unsigned char c;
	if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
	
	switch (c) {
	case '$':
		if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
		switch (c) {
		case '@': return(KC_JIS0208);
		case 'B': return(KC_JIS0208);
		case '(': if (**pSrc) { c = **pSrc; (*pSrc)++; }
		          	else return(KC_UNKNOWN);
		          if (c != 'D') return(KC_UNKNOWN);
		          return(KC_JIS0212);
		default:  return(KC_UNKNOWN);
		}
	case '&':
		if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
		if (c != '@')  return(KC_UNKNOWN);
		if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
		if (c != 0x1B) return(KC_UNKNOWN);
		if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
		if (c != '$')  return(KC_UNKNOWN);
		if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
		if (c != 'B')  return(KC_UNKNOWN);
		return(KC_JIS0208);
	case '(':
		if (**pSrc) { c = **pSrc; (*pSrc)++; } else return(KC_UNKNOWN);
		switch (c) {
		case 'J': return(KC_ASCII);
		case 'H': return(KC_ASCII);
		case 'B': return(KC_ASCII);
		case 'I': return(KC_HANKANA);
		default:  return(KC_UNKNOWN);
		}
	}
	return(KC_UNKNOWN);
}

//------------------------------------------------

int kcode_charsize_s(const unsigned char* pChr) {
	unsigned char c, c2;
	c  = *pChr;
	if (!c) return(0);
	c2 = pChr[1];
	
	// JIS漢字
	
	if (c >= 0x81 && c <= 0x9F ||
	    c >= 0xE0 && c <= 0xF7) {
		if (!c2) return(-1);
		if (c2 >= 0x40 && c2 <= 0x7E ||
		    c2 >= 0x80 && c2 <= 0xFC) {
			return(2);
		} else {
			return(-2);
		}
	}
	
	// Vodafone 絵文字 (1B 24 ? ? ... 0F)
	
	if (c == 0x1B) {
		int l = 1;
		pChr++;
		while (*pChr != 0x0F && *pChr != 0x00) {
			l++; pChr++;
		}
		return(-l);
	}
	
	if (c >= 0x20 && c <= 0x7E) return(1); // 通常ASCII
	if (c >= 0xA1 && c <= 0xDF) return(1); // 半角カナ
	
	if (c <= 0x1F || c == 0x7F || c == 0xFF) {
		return(_kc_is_safe_ascii(c) ? 1 : -1);
	}
	return(-2);
}

//------------------------------------------------

int kcode_charsize_e(const unsigned char* buf) {
	switch (*buf) {
		case 0x00: return(0);
		case 0x8E: return(2); // 半角カナ
		case 0x8F: return(3); // 補助漢字
		default:
			if (*buf >= 0xA1 && *buf <= 0xFE) return(2); // 漢字
			return(1); // それ以外
	}
}
