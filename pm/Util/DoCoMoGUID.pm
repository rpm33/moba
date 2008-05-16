package Util::DoCoMoGUID;

=pod
----------------------------------------------------------------------
<form>, <a> ������ guid=ON ���ɲä���⥸�塼��

�����Ƥ��Ф��� guid=ON ���ɲä�����֤ˤʤäƤ���Τǡ�
  ���ʬ����ɬ�פʤ餳�Υ⥸�塼��������Ƥ���������
----------------------------------------------------------------------
=cut

use strict;

sub addGuidReq {
	my ($rHtml) = @_;
	
	${$rHtml} =~ s(<(a|form)\s+([^<>]+)>) {
		my ($tag, $in) = ($1, $2);
		
		my $is_form_get =
			($tag =~ /^form$/i && $in !~ /method="post"/i) ? 1 : 0;
		my $noguid = 0;
		
		$in =~ s((href|action)="([^"]+)") {
			my ($key, $path) = ($1, $2);
			
			$noguid = 1 if ($path =~ /[&?]guid=ON/);
			
			my $add = '';
			if ($path =~ /(.*)#(.*)/) {
				$add = "#$2"; $path = $1;
			}
			if ($path ne '' && !$is_form_get && !$noguid) {
				$path .= ($path =~ /\?/ ? '&' : '?'). 'guid=ON';
			}
			qq|$key="$path$add"|;
		}egis;
		
		if ($is_form_get && !$noguid) {
			qq|<$tag $in>|.
			qq|<input type="hidden" name="guid" value="ON">|;
		} else {
			qq|<$tag $in>|;
		}
	}egis;
}

1;
