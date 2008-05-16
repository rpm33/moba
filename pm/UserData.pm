package UserData;

=pod
----------------------------------------------------------------------
�桼����������⥸�塼��

���ꥯ��������ˡ�uid �ʤɤ򥭡��ˡ��桼���������� DB ����������롣
_getInfo ����Ǽ������륫���ϡ������ӥ���ɬ�פ˱������ѹ����뤳�ȡ�
�桼��ǧ�ڤˤɤΤ褦���������Ѥ��뤫�ϥ����ӥ��ˤ�äưۤʤ롣
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;

# new ������ MobileEnv::set() �μ¹Ԥ�ɬ��

sub new {
	my ($pkg) = @_;
	my $self = {};
	bless($self, $pkg);
	
	# UID_ST: UID�������ơ�����
	#   0:����ʤ� 3:serial/uid ����
	# �ʢ����ơ������μ���ϥ����ӥ������
	
	$self->{UID_ST}  = 0;
	
	# USER_ST: �����Ͽ���ơ�����
	#   0:���� 1:����ʥᥢ��̤ǧ�ڡ� 2:����ʥᥢ��ǧ�ںѡ�
	# �ʢ����ơ������μ���ϥ����ӥ������
	
	$self->{USER_ST} = 0;
	
	# SERV_ST: �����ӥ����ѥ��ơ����� (�ʲ���­�������)
	#  1:������� 2:�������
	#  4:�ڥʥ�ƥ��� 8:�᡼����ã������ǽ
	# �ʢ����ơ������μ���ϥ����ӥ������
	
	$self->{SERV_ST} = 0; 
	
	if ($_::F->{_u}) {
		
		# http://host/.*****/ �� ***** ����ʬ�� _u �����롣
		# �Ȥ����ϥ����ӥ����衣�ƥ�ץ쥳��ѥ�������Хѥ���
		# ���ܤ���褦�ˤ��Ƥ���Τ� _u �ξ���Ͼä��ʤ���
		
		$self->{URL_INFO_C} = $self->{URL_INFO} = $_::F->{_u};
		
		# URL_INFO_C : URL ���Ϥ��줿����
		# URL_INFO   : URL ���Ϥ�����
		
		# URL_INFO_C ne URL_INFO �ˤʤ�ȡ�
		# URL �˥ǡ������������URL�˼�ư������쥯�Ȥ���롣
		
		# docomo �� SSL ���ܤʤɤǻ��Ѥ���Τ���
	}
	
	$self->getInfo() if (!$_::BYPASS_FUNC{$_::F->{f}});
	
	return($self);
}

#--------------------------------------------------------
# �����ݻ�ʸ���������

sub makeInfoStr {
	my $self = shift;
	
	if ($self->{URL_INFO}) {
		return "/.". $self->{URL_INFO};
	}
}

#=====================================================================
#                        �桼������μ���
#=====================================================================

sub getInfo {
	my $self = shift;
	if ($ENV{MB_UID}) {
		$self->_getInfo('subscr_id', $ENV{MB_UID});
		$self->{UID_ST} = 3 if ($self->{UID_ST} < 3);
	}
}
sub _getInfo {
	my ($self, $column, $value) = @_;
	
	my $dbh = DA::getHandle($_::DB_USER_R);
	my $sth = $dbh->prepare(<<"SQL");
	select
		user_id, user_st, serv_st,
		model_name
	from user_data where $column=?
SQL
	$sth->execute($value);
	
	if ($sth->rows) {
		($self->{USER_ID}, $self->{USER_ST}, $self->{SERV_ST},
		 $self->{REG_MODEL})
		 = $sth->fetchrow_array();
	}
}

1;

