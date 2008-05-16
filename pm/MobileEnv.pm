package MobileEnv;

=pod
----------------------------------------------------------------------
モバイル特有の情報を環境変数にセットするモジュール

MB_CARRIER_IP 接続元IP から判別したキャリア
MB_CARRIER_UA User-Agetn から判別したキャリア
MB_MODEL_TYPE 機種タイプ
               imode    DM=MOVA DF=FOMA
               ezweb    AH=HDML端末 AU=WAP2.0端末
               softbank VC=C型 VP=P型 VW=W型 VG=3GC型
MB_MODEL_NAME 機種名 (UA なので、au は機種名と異なります)

MB_UID        iモードID, ez番号, Softbank uid
MB_SERIAL     FOMA カード番号 / 端末製造番号

MB_CHARS_W    ブラウザ横文字数（半角）
MB_CHARS_H    ブラウザ縦文字数
MB_BROWSER_W  ブラウザ幅(px)
MB_BROWSER_H  ブラウザ高さ(px)
MB_BROWSER_W2 ブラウザ幅(px) （スクロールバーぶんを引いたもの）

※以下、モバイルの情報ではないが。

MB_SSL        SSL でのリクエストの場合'1'

MB_DOMAIN     サービスのドメイン
MB_HTTP_HOST  サービスのホスト名(http)
MB_HTTPS_HOST サービスのホスト名(https)
              ↑キャリアによってホスト名を変えたりする場合があるため

MB_SERV_LV    その端末をサポートするか？ (-1:非対応 1〜:対応)

※必要に応じてこのモジュールに必要な情報取得ロジックを追加していく。
※一般向け資料に掲載されていないヘッダ値は除去しています。
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;
use Util::IPIdent;

# 接続元IP判別設定ファイルのロード

Util::IPIdent::init(@_::IPIDENT_FILES);

sub set {
	
	#-------------------------
	# fcgi が勝手にクリアするが一応
	
	for my $key (sort keys %ENV) {
		delete($ENV{$key}) if ($key =~ /^MB_/);
	}
	
	#-------------------------
	
	if ($ENV{SERVER_PORT} == 443) {
		$ENV{MB_SSL} = 1;
	}
	
	#-------------------------
	# 接続元IPアドレスでキャリア判別
	
	my $ret = Util::IPIdent::get($ENV{REMOTE_ADDR});
	if ($ret eq 'X' && $ENV{HTTP_X_FORWARDED_FOR}) {
		$ret = Util::IPIdent::get($ENV{HTTP_X_FORWARDED_FOR});
	}
	if ($ret) {
		$ENV{MB_CARRIER_IP} = $ret;
	} else {
		$ENV{MB_CARRIER_IP} = '-';
	}
	
	#-------------------------
	# 機種情報を取得
	
	parseEnv();
	
# ここで機種情報DBから機種別の設定（個別の対応可非など）をもってくるが割愛。
# DB から取得した個別情報はキャッシュしておく。
	
	setDefault();
	
	if ($_::DEBUG_FAKE_UID &&
		($_::DEBUG_ALLOW_PC || $ENV{MB_CARRIER_IP} eq 'I') &&
		$ENV{HTTP_USER_AGENT} =~ /;([U])=(.*)/) {
		
		$ENV{MB_UID}    = $2 if ($1 eq 'U');
	}
	
	#-------------------------
	# HTTP ホスト名
	
	$ENV{MB_DOMAIN}      = $_::DOMAIN;
	$ENV{MB_HTTP_HOST}   = $_::HTTP_HOST;
	$ENV{MB_HTTPS_HOST}  = $_::HTTPS_HOST;
	
	$ENV{MB_BROWSER_W2}  = $ENV{MB_BROWSER_W};
	$ENV{MB_BROWSER_W2} -= 10 if ($ENV{MB_CARRIER_UA} ne 'D');
}

#=====================================================================
#                           端末情報
#=====================================================================

sub parseEnv {
	
	#-------------------------
	# DoCoMo:MOVA
	
	if ($ENV{HTTP_USER_AGENT} =~ m#^DoCoMo/([\d\.]+)/([^\s/]+)#i) {
		my $spec = $';
		$ENV{MB_CARRIER_UA} = 'D';
		$ENV{MB_MODEL_TYPE} = 'DM';
		$ENV{MB_MODEL_NAME} = $2;
		
		if ($ENV{HTTP_X_DCMGUID}) {
			$ENV{MB_UID} = $ENV{HTTP_X_DCMGUID};
		}
		if ($spec =~ m#^/c(\d+)(/(T[BCDJ])(/W([\d\.]+)H([\d\.]+))?)?#) {
			my ($c, $t, $w, $h) = ($1, $3, $5, $6);
			$spec = $';
			$ENV{MB_CHARS_W} = $w if ($w);
			$ENV{MB_CHARS_H} = $h if ($h);
			if ($spec =~ m#/ser([\da-z]{11,15})(/icc([\da-z]{20}))?#i) {
				$ENV{MB_SERIAL}  = $3 ? $3 : $1 ? $1 : undef;
			}
		} else {
			# HTML3.0 以上なら必ず cache 指定まではある
		}
		return;
	}
	
	#-------------------------
	# DoCoMo:FOMA
	
	elsif ($ENV{HTTP_USER_AGENT} =~ m#^DoCoMo/([\d\.]+) ([^\s\(]+)#i) {
		my $spec = $';
		$ENV{MB_CARRIER_UA} = 'D';
		$ENV{MB_MODEL_TYPE} = 'DF';
		$ENV{MB_MODEL_NAME} = $2;
		
		if ($ENV{HTTP_X_DCMGUID}) {
			$ENV{MB_UID} = $ENV{HTTP_X_DCMGUID};
		}
		if ($spec =~ m#^\s*\(c(\d+)(;(T[BCDJ])(;W([\d\.]+)H([\d\.]+))?)?#) {
			my ($c, $t, $w, $h) = ($1, $3, $5, $6);
			$spec = $';
			$ENV{MB_CHARS_W} = $w if ($w);
			$ENV{MB_CHARS_H} = $h if ($h);
			if ($spec =~ m#;icc([\da-zA-Z]{20})#) {
				$ENV{MB_SERIAL} = $1;
			} elsif ($spec =~ m#;ser([\da-zA-Z]{15})#) {
				$ENV{MB_SERIAL} = $1;
			}
		}
		return;
	}
	
	#-------------------------
	# VODAFONE
	
	elsif ($ENV{HTTP_USER_AGENT} =~ m#^(J-PHONE|Vodafone|SoftBank)/([^/]+)/([^/ ]+)#i) {
		$ENV{MB_CARRIER_UA} = 'V';
		$ENV{MB_MODEL_NAME} = $3;
		my $v = $2;
		
		if ($ENV{MB_MODEL_NAME} =~ /_[a-z]$/) { # マイナーバージョンを省略
			$ENV{MB_MODEL_NAME} = $`;
		}
		
		$ENV{MB_MODEL_TYPE} = 
			($v eq '1.0') ? 'VG' : # 3GC 型
			($v eq '2.0') ? 'VC' : # C2  型
			($v eq '3.0') ? 'VC' : # C   型
			($v =~ /^4/ ) ? 'VP' : # P   型
			($v =~ /^5/ ) ? 'VW' : # W   型
			                'V';
		
		if ($ENV{HTTP_X_JPHONE_DISPLAY} =~ /^(\d+)\*(\d+)$/) {
			$ENV{MB_BROWSER_W} = $1; $ENV{MB_BROWSER_H} = $2;
		}
		if (length($ENV{HTTP_X_JPHONE_UID}) < 10) {
			$ENV{HTTP_X_JPHONE_UID} = '';
		}
		if ($ENV{HTTP_X_JPHONE_UID}) {
			$ENV{MB_UID} = $ENV{HTTP_X_JPHONE_UID};
		}
		return;
	}
	
	#-------------------------
	# EZWEB:WAP2.0+
	
	elsif ($ENV{HTTP_USER_AGENT} =~ m#^KDDI-([^ ]+)#i) {
		$ENV{MB_CARRIER_UA} = 'A';
		$ENV{MB_MODEL_TYPE} = 'AU';
		$ENV{MB_MODEL_NAME} = $1;
		
		if ($ENV{HTTP_X_UP_SUBNO}) {
			$ENV{MB_UID} = $ENV{HTTP_X_UP_SUBNO};
		}
		if ($ENV{HTTP_X_UP_DEVCAP_SCREENPIXELS} =~ /^(\d+),(\d+)$/) {
			$ENV{MB_BROWSER_W} = $1; $ENV{MB_BROWSER_H} = $2;
		}
		if ($ENV{HTTP_X_UP_DEVCAP_SCREENCHARS} =~ /^([\d\.]+),([\d\.]+)$/) {
			$ENV{MB_CHARS_W} = $1; $ENV{MB_CHARS_H} = $2;
		}
		return;
	}
	
	#-------------------------
	# EZWEB:HDML
	
	elsif ($ENV{HTTP_USER_AGENT} =~ m#^UP.Browser/[^\-]*-([^ ]+)#i) {
		$ENV{MB_CARRIER_UA} = 'A';
		$ENV{MB_MODEL_NAME} = $1;
		$ENV{MB_MODEL_TYPE} = 'AH';
		if ($ENV{HTTP_X_UP_SUBNO}) {
			$ENV{MB_UID} = $ENV{HTTP_X_UP_SUBNO};
		}
		return;
	}
	
	#-------------------------
	# それ以外
	
	else {
		$ENV{MB_CARRIER_UA} = '-';
		$ENV{MB_MODEL_NAME} = '-';
		return;
	}
}

#--------------------------------------------------------
# 端末情報DBから情報が取得できなかった場合のデフォルト値

sub setDefault {
	$ENV{MB_CHARS_W}   =  20 if (!$ENV{MB_CHARS_W});
	$ENV{MB_CHARS_H}   =  10 if (!$ENV{MB_CHARS_H});
	$ENV{MB_BROWSER_W} = 240 if (!$ENV{MB_BROWSER_W});
	$ENV{MB_BROWSER_H} = 320 if (!$ENV{MB_BROWSER_H});
	
	if (!$ENV{MB_SERV_LV}) {
		if ($ENV{MB_CARRIER_UA} eq 'D') {
			if ($ENV{MB_MODEL_TYPE} eq 'DF') {
				my $series = ($ENV{MB_MODEL_NAME} =~ /\d{3,4}/) ? $& : '';
				if ($series =~ /^2001|2002|2101$/) {
					$ENV{MB_SERV_LV} = -1;
				}
				$ENV{MB_SERV_LV} =  2;
			} else {
				$ENV{MB_SERV_LV} = -1;
			}
		}
		elsif ($ENV{MB_CARRIER_UA} eq 'A') {
			if ($ENV{MB_MODEL_NAME} =~ /^..3/) {
				$ENV{MB_SERV_LV} = 2;
			} else {
				$ENV{MB_SERV_LV} = -1;
			}
		}
		elsif ($ENV{MB_CARRIER_UA} eq 'V') {
			if ($ENV{MB_MODEL_TYPE} eq 'VG') {
				$ENV{MB_SERV_LV} =  2;
			} else { # C,P,W 型
				$ENV{MB_SERV_LV} = -1;
			}
		}
		else {
			$ENV{MB_SERV_LV} = -1;
		}
	}
}

1;
