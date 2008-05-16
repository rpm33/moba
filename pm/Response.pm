package Response;

=pod
----------------------------------------------------------------------
HTTP �쥹�ݥ󥹤�����
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;
use HTMLFast;
use SoftbankEncode;
use Util::DoCoMoGUID;

#-----------------------------------------------------------
# html �ڡ������֤��ʥ�Х����ѡ�

sub output {
	my ($rHtml, $cache) = @_;
	
	# ��ʸ����ü���Υ���ꥢ�������Ѵ�
	
	my $html = $_::MCODE->u2any(${$rHtml}, $ENV{MB_CARRIER_UA});
	
	# i�⡼��ID�׵���ɲ�
	
	if ($ENV{MB_CARRIER_UA} eq 'D') {
		Util::DoCoMoGUID::addGuidReq(\$html);
	}
	
	my $charset = 'Shift_JIS';
	
	if ($ENV{MB_MODEL_TYPE} eq 'VG') {
		
		# softbank �� 3G �ϡ��ڡ����� UTF8 �ˤ��ʤ��ȥե����फ��
		# ��ʸ������������ʤ�����
		
		$charset = 'UTF-8';
		$html = SoftbankEncode::sjis_to_utf8($html);
	}
	
	# content-type �����Ƥ򸫤Ʒ���
	
	my $head = substr($html, 0, 100);
	if ($head =~ /<\?\s*xml/) {
		if ($ENV{MB_CARRIER_IP} eq 'I') {
			
			# ����ʤɤ����̾�Υ֥饦���Ǹ�����ˡ�
			# content-type �� xhtml �Ȥ����֤���ɽ��������뤿�ᡣ
			
			print "Content-type: text/html; charset=$charset\r\n";
		} else {
			print "Content-type: application/xhtml+xml; charset=$charset\r\n";
		}
	} else {
		print "Content-type: text/html; charset=$charset\r\n";
	}
	
	$html = '' if ($ENV{REQUEST_METHOD} eq 'HEAD');
	
	my $len = length($html);
	print "Content-length: $len\r\n";
	
	# FOMA �Ǥϡ�no-cache ����ꤹ��ȡ��֥饦���Хå��ξ��Ǥ�
	# ���ɤ߹��ߤ����Τǡ����Τ褦�ʵ�ư�ˤ��Ƥ��롣
	
	# au �ϥ���å��夬�����Τǡ�ɬ�� no-cache ���դ��롣
	# no-cache ���դ��Ƥ⡢�ʤࡿ���Ǥϥ���å��夷��
	# �ڡ������Ȥ���ΤǤ������ʤ���
	
	my $nocache =
		($cache eq 'no-cache') ? 1 :
		($cache eq 'cache')    ? 0 :
		($ENV{REQUEST_METHOD} eq 'POST') ? 0 :
		($ENV{MB_MODEL_TYPE}  eq 'DF'  ) ? 0 : 1;
	
	if ($nocache) {
		print "Cache-control: no-cache\r\n";
		print "Pragma: no-cache\r\n";
	}
	
	print "Connection: close\r\n";
	print "\r\n$html";
}

#-----------------------------------------------------------
# ������쥯��

sub redirect {
	my $url = shift;
	print "Location: $url\r\n";
	print "Connection: close\r\n";
	print "\r\n";
}

1;
