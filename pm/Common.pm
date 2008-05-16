package Common;

=pod
----------------------------------------------------------------------
�桼�ƥ���ƥ����Ϥζ��̽����������⥸�塼��

�ڤ�ʽ����Ϥ����������
----------------------------------------------------------------------
=cut

use strict;
use HTMLFast;

our $CHARS =
	'0123456789'.
	'abcdefghijklmnopqrstuvwxyz'.
	'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

#-----------------------------------------------------------
# ����Ĺ�Υ�����ʸ��������

sub makeRandomString {
	my $len = shift;
	my $l = length($CHARS);
	my $str;
	for (1..$len) {
		$str .= substr($CHARS, int(rand($l)), 1);
	}
	return($str);
}

#-----------------------------------------------------------
# Ϳ����줿�ϥå����ե���󥹤� hidden �����Υꥹ�Ȥˤ���

sub makeHidden {
	my ($rhParams) = @_;
	my $ret = '';
	for my $k (keys(%{$rhParams})) {
		my $key = HTMLFast::htmlspecialchars($k);
		my $val = HTMLFast::htmlspecialchars($rhParams->{$k});
		$ret .= qq|<input type="hidden" name="$key" value="$val">\n|;
	}
	return($ret);
}

#------------------------------------------------------------
# Ϳ����줿�ϥå����ե���󥹤� QUERY_STRING �����ˤ���

# option: $d1, $d2, $d3 ����ꤹ�뤳�Ȥǡ��̤Υ��󥳡�����ˡ��Ȥ��롣

sub makeParams {
	my ($rhParams, $d1, $d2, $d3) = @_;
	my @qs;
	
	$d1 = '&' if (!$d1);
	$d2 = '=' if (!$d2);
	$d3 = '%' if (!$d3);
	
	for my $key (sort keys(%{$rhParams})) {
		my $val = $rhParams->{$key};
		next if ($val eq '' || $key eq 'f');
		my $key  = HTMLFast::encode($key, $d3);
		my $val  = HTMLFast::encode($val, $d3);
		
		push(@qs, "$key$d2$val");
	}
	return(join($d1, @qs));
}

#-----------------------------------------------------------
# �ϥå����ʣ������

# ����: $rHash: �ϥå����ե����
#       $match: ��������ɽ���˥ޥå����륭���Τ�ʣ�� (option)
# ����: �ϥå����ե����

sub cloneHash {
	my ($rHash, $match) = @_;
	my %newHash;
	
	if ($match) {
		for my $key (keys(%{$rHash})) {
			if ($key =~ /$match/) {
				$newHash{$key} = $rHash->{$key};
			}
		}
	} else {
		for my $key (keys(%{$rHash})) {
			$newHash{$key} = $rHash->{$key};
		}
	}
	
	return(\%newHash);
}

#-----------------------------------------------------------
# �ϥå����ޡ�������

# ����: $rDstHash: �ޡ�����ϥå����ե����
#       $rSrcHash: �ޡ������ϥå����ե����
#       $match: ��������ɽ���˥ޥå����륭���Τߥޡ��� (option)

sub mergeHash {
	my ($rDstHash, $rSrcHash, $match) = @_;
	
	if ($match) {
		for my $key (keys(%{$rSrcHash})) {
			if ($key =~ /$match/) {
				$rDstHash->{$key} = $rSrcHash->{$key};
			}
		}
	} else {
		for my $key (keys(%{$rSrcHash})) {
			$rDstHash->{$key} = $rSrcHash->{$key};
		}
	}
}


1;
