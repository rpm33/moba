package SoftbankEncode;

use 5.008;
use strict;
use warnings;
use Encode;
use Encode::Unicode;

require Exporter;
our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw( ) ] );
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT      = qw( );
our $VERSION     = '0.01';

require XSLoader;
XSLoader::load('SoftbankEncode', $VERSION);

#-----------------------------------------------------------------------------
# UTF-8 ɽ���� (Softbank��ʸ�� Unicode ɽ����ޤ�) ʸ����� Shift_JIS ���Ѵ�
#
# ���ºݤˤϳ�ĥʸ�����б����뤿�� "SHIFT_JIS" �ǤϤʤ� "CP932" ������

sub utf8_to_sjis {
	my ($t) = @_;
	
	$t = Encode::encode("UTF-16LE", Encode::decode("utf8", $t));
	$t = SoftbankEncode::unicodeToEscaped($t, length($t));
	
	my @words = ();
	my $w = '';
	while ($t) {
		my $c = substr($t, 0, 2);  $t = substr($t, 2);
		if ($c eq "\x1c\x30") {
			if ($w) {
				push(@words, $w);
				$w = '';
			}
			push(@words, $c);
		} else {
			$w .= $c;
		}
	}
	if ($w) {
		push(@words, $w);
		$w = '';
	}
	
	my $result = '';
	for my $w (@words) {
		if ($w eq "\x1c\x30") {
			$result .= "\x81\x60";
		} else {
			$result .= Encode::encode("cp932", Encode::decode("UTF-16LE", $w));
		}
	}
	return $result;
}

#-----------------------------------------------------------------------------
# Shift_JIS ʸ����� UTF-8 ɽ�����Ѵ�
#
# ���ºݤˤϳ�ĥʸ�����б����뤿�� "SHIFT_JIS" �ǤϤʤ� "CP932" ������

sub sjis_to_utf8 {
	my ($t) = @_;
	$t = Encode::encode("UTF-16LE", Encode::decode("cp932", $t));
	$t = SoftbankEncode::escapedToUnicode($t, length($t));
	$t = Encode::encode("utf8", Encode::decode("UTF-16LE", $t));
	return $t;
}

1;
__END__

=head1 NAME

SoftbankEncode - Softbank ��ʸ����ޤ� UTF8 - Shift_JIS ʸ�����Ѵ����󶡤��� Perl extension

=head1 SYNOPSIS

  use SoftbankEncode;

  text = SoftbankEncode::utf8_to_sjis(text);
  text = SoftbankEncode::sjis_to_utf8(text);

=head1 ABSTRACT

  Converts between UTF-8 string (including Softbank Emoticon characters
  represented in Unicode form) and Shift_JIS string (where we need to
  use escaped multibyte sequence for Softbank Emoticon characters).

=head1 DESCRIPTION

3G ü���ˤ����Ƥϡ��ڡ�����ʸ�������ɤȤ��� UTF-8 ��Ȥ�ʤ���
�桼������ Softbank ��ʸ���������� FORM �������뤳�Ȥ��Ǥ��ʤ���
�������򤹤뤿��ˡ�Softbank ��ʸ����ޤ� UTF8 / Shift_JIS ʸ
����֤��Ѵ������򤳤Υ⥸�塼����󶡤��롣

=head2 EXPORT

�ʤ�

=head1 SEE ALSO

Softbank �γ�ʸ������ˤĤ��ƤΥɥ������
http://developers.softbankmobile.co.jp/dp/tool_dl/web/picword_top.php

=head1 AUTHOR

Ryosuke Matsuuchi

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by (C) DeNA

=cut
