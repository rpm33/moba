package MException;

=pod
----------------------------------------------------------------------
�㳰�����ط�

�����λ�����ˡ�����ܡ�

eval {
	MException::error("error message", { CODE => 1234 });
};
if ($@) {
	my $e   = MException::getInfo();
	my $msg = MException::makeMsg($e);
}

���顼�����ɤΥޥ������äˤʤ���

4001: DB ���ꥨ�顼
4002: DB ��³���顼
4003: DB commit ���顼
4004: DB commit ���顼����ʬ���ߥåȡ�
4005: DB rollback ���顼
5003: POST �ꥯ�������ɤ߹��ߥ��顼

���ꥨ�顼�δƻ�򤹤뤿��˺�ä�����
��ɥ��顼��å������Ǵƻ뤷���ۤ�������ץ�ʤΤǡ�
�Ƕ�ϥ��顼����ñ��� die ����ۤ���¿����̵�����ƻȤ�ɬ�פϤʤ���

MException::throw �Τۤ��ϡ�������쥯�Ȥ� function �ѹ��ʤɤǻȤäƤ��롣
----------------------------------------------------------------------
=cut

use FileHandle;

my $gInfo; # ľ����㳰����

my %conv = (
"\r" => '%0D',
"\n" => "%0A",
"\t" => "%09",
"%"  => "%25",
);

#-----------------------------------------------------------
# ���顼����

# $msg:     ���顼��å�����
# $rParams: �ѥ�᡼���ϥå����ե����(*1)
# 
# (*1) �����Ϥ�����Ǥ��

sub error {
	my ($msg, $rParams) = @_;
	if ($rParams) {
		$gInfo = $rParams;
	} else {
		$gInfo = {};
	}
	$gInfo->{_T}  = 'ERR';
	$gInfo->{MSG} = $msg;
	
	if (!exists($gInfo->{_P})) {
		($gInfo->{_P}, $gInfo->{_F}, $gInfo->{_L}) = caller;
	}
	
	die "Exception\n";
}

#-----------------------------------------------------------
# �㳰 throw

# ������: �ѥ�᡼���ϥå����ե����(*1)
# 
# (*1) �����Ϥ�����Ǥ�դ����������ѥ�᡼���� Page/Main.pm ��
#      catch ����ơ���ͭ��ư���Ԥ���
# 
#    CHG_FUNC  => 'func_name' : �̤� function ������Ū�˥�����쥯��
#    REDIRECT  => 'url'       : ���� url �˥�����쥯�Ȥ�����
#    REDIRECT2 => 1           : ������ url �˥�����쥯��

sub throw {
	$gInfo = shift;
	
	if (!exists($gInfo->{_P})) {
		($gInfo->{_P}, $gInfo->{_F}, $gInfo->{_L}) = caller;
	}
	die "Exception\n";
}

#-----------------------------------------------------------
# �㳰�����ʸ����

sub makeMsg {
	my $rHash = shift;
	my $msg = '';
	
	if (!$rHash->{_LITE}) {
		if ($rHash->{_P}) {
			$msg = "$rHash->{_P}:$rHash->{_F}:$rHash->{_L}\t";
		} else {
			my @caller = caller;
			$msg = "$caller[0]:$caller[1]:$caller[2]\t";
		}
	}
	
	for my $key (sort keys(%{$rHash})) {
		next if ($key =~ /^_/);
		my $val = $rHash->{$key};
		$val =~ s/[\r\n\t\%]/$conv{$&}/g;
		if ($msg) {
			$msg .= "\t$key:$val";
		} else {
			$msg = "$key:$val";
		}
	}
	
	return($msg);
}

#-----------------------------------------------------------
# ľ����㳰����������

# ���̤� die ���������㳰����Τ��������Ѵ����롣

sub getInfo {
	my $msg = $@;
	$@ = undef;
	return($gInfo) if ($msg eq "Exception\n");
	
	$gInfo = {};
	$gInfo->{_T}  = 'ERR';
	$gInfo->{_P}  = '-';
	$gInfo->{_F}  = '-';
	$gInfo->{_L}  = '-';
	$gInfo->{MSG} = $msg;
	$gInfo->{MSG} =~ s/\n$//;
	return($gInfo);
}

1;
