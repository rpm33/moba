package MobileEnv;

=pod
----------------------------------------------------------------------
��Х�����ͭ�ξ����Ķ��ѿ��˥��åȤ���⥸�塼��

MB_CARRIER_IP ��³��IP ����Ƚ�̤�������ꥢ
MB_CARRIER_UA User-Agetn ����Ƚ�̤�������ꥢ
MB_MODEL_TYPE ���勵����
               imode    DM=MOVA DF=FOMA
               ezweb    AH=HDMLü�� AU=WAP2.0ü��
               softbank VC=C�� VP=P�� VW=W�� VG=3GC��
MB_MODEL_NAME ����̾ (UA �ʤΤǡ�au �ϵ���̾�Ȱۤʤ�ޤ�)

MB_UID        i�⡼��ID, ez�ֹ�, Softbank uid
MB_SERIAL     FOMA �������ֹ� / ü����¤�ֹ�

MB_CHARS_W    �֥饦����ʸ������Ⱦ�ѡ�
MB_CHARS_H    �֥饦����ʸ����
MB_BROWSER_W  �֥饦����(px)
MB_BROWSER_H  �֥饦���⤵(px)
MB_BROWSER_W2 �֥饦����(px) �ʥ�������С��֤���������Ρ�

���ʲ�����Х���ξ���ǤϤʤ�����

MB_SSL        SSL �ǤΥꥯ�����Ȥξ��'1'

MB_DOMAIN     �����ӥ��Υɥᥤ��
MB_HTTP_HOST  �����ӥ��Υۥ���̾(http)
MB_HTTPS_HOST �����ӥ��Υۥ���̾(https)
              ������ꥢ�ˤ�äƥۥ���̾���Ѥ����ꤹ���礬���뤿��

MB_SERV_LV    ����ü���򥵥ݡ��Ȥ��뤫�� (-1:���б� 1��:�б�)

��ɬ�פ˱����Ƥ��Υ⥸�塼���ɬ�פʾ���������å����ɲä��Ƥ�����
�����̸��������˷Ǻܤ���Ƥ��ʤ��إå��ͤϽ���Ƥ��ޤ���
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;
use Util::IPIdent;

# ��³��IPȽ������ե�����Υ���

Util::IPIdent::init(@_::IPIDENT_FILES);

sub set {
	
	#-------------------------
	# fcgi ������˥��ꥢ���뤬���
	
	for my $key (sort keys %ENV) {
		delete($ENV{$key}) if ($key =~ /^MB_/);
	}
	
	#-------------------------
	
	if ($ENV{SERVER_PORT} == 443) {
		$ENV{MB_SSL} = 1;
	}
	
	#-------------------------
	# ��³��IP���ɥ쥹�ǥ���ꥢȽ��
	
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
	# �����������
	
	parseEnv();
	
# �����ǵ������DB���鵡���̤�����ʸ��̤��б�����ʤɡˤ��äƤ��뤬�䰦��
# DB ��������������̾���ϥ���å��夷�Ƥ�����
	
	setDefault();
	
	if ($_::DEBUG_FAKE_UID &&
		($_::DEBUG_ALLOW_PC || $ENV{MB_CARRIER_IP} eq 'I') &&
		$ENV{HTTP_USER_AGENT} =~ /;([U])=(.*)/) {
		
		$ENV{MB_UID}    = $2 if ($1 eq 'U');
	}
	
	#-------------------------
	# HTTP �ۥ���̾
	
	$ENV{MB_DOMAIN}      = $_::DOMAIN;
	$ENV{MB_HTTP_HOST}   = $_::HTTP_HOST;
	$ENV{MB_HTTPS_HOST}  = $_::HTTPS_HOST;
	
	$ENV{MB_BROWSER_W2}  = $ENV{MB_BROWSER_W};
	$ENV{MB_BROWSER_W2} -= 10 if ($ENV{MB_CARRIER_UA} ne 'D');
}

#=====================================================================
#                           ü������
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
			# HTML3.0 �ʾ�ʤ�ɬ�� cache ����ޤǤϤ���
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
		
		if ($ENV{MB_MODEL_NAME} =~ /_[a-z]$/) { # �ޥ��ʡ��С��������ά
			$ENV{MB_MODEL_NAME} = $`;
		}
		
		$ENV{MB_MODEL_TYPE} = 
			($v eq '1.0') ? 'VG' : # 3GC ��
			($v eq '2.0') ? 'VC' : # C2  ��
			($v eq '3.0') ? 'VC' : # C   ��
			($v =~ /^4/ ) ? 'VP' : # P   ��
			($v =~ /^5/ ) ? 'VW' : # W   ��
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
	# ����ʳ�
	
	else {
		$ENV{MB_CARRIER_UA} = '-';
		$ENV{MB_MODEL_NAME} = '-';
		return;
	}
}

#--------------------------------------------------------
# ü������DB������󤬼����Ǥ��ʤ��ä����Υǥե������

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
			} else { # C,P,W ��
				$ENV{MB_SERV_LV} = -1;
			}
		}
		else {
			$ENV{MB_SERV_LV} = -1;
		}
	}
}

1;
