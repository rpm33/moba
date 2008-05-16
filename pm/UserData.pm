package UserData;

=pod
----------------------------------------------------------------------
ユーザ情報取得モジュール

１リクエスト毎に、uid などをキーに、ユーザ情報を毎回 DB から取得する。
_getInfo の中で取得するカラムは、サービスの必要に応じて変更すること。
ユーザ認証にどのような方式を用いるかはサービスによって異なる。
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;

# new の前に MobileEnv::set() の実行が必要

sub new {
	my ($pkg) = @_;
	my $self = {};
	bless($self, $pkg);
	
	# UID_ST: UID送信ステータス
	#   0:情報なし 3:serial/uid あり
	# （※ステータスの種類はサービス次第）
	
	$self->{UID_ST}  = 0;
	
	# USER_ST: 会員登録ステータス
	#   0:非会員 1:会員（メアド未認証） 2:会員（メアド認証済）
	# （※ステータスの種類はサービス次第）
	
	$self->{USER_ST} = 0;
	
	# SERV_ST: サービス利用ステータス (以下を足したもの)
	#  1:自主退会 2:運用退会
	#  4:ペナルティー 8:メール不達だと不能
	# （※ステータスの種類はサービス次第）
	
	$self->{SERV_ST} = 0; 
	
	if ($_::F->{_u}) {
		
		# http://host/.*****/ の ***** の部分が _u に入る。
		# 使い方はサービス次第。テンプレコンパイラで相対パスで
		# 遷移するようにしているので _u の情報は消えない。
		
		$self->{URL_INFO_C} = $self->{URL_INFO} = $_::F->{_u};
		
		# URL_INFO_C : URL で渡された情報
		# URL_INFO   : URL で渡す情報
		
		# URL_INFO_C ne URL_INFO になると、
		# URL にデータを埋め込んだURLに自動リダイレクトされる。
		
		# docomo の SSL 遷移などで使用するのが。
	}
	
	$self->getInfo() if (!$_::BYPASS_FUNC{$_::F->{f}});
	
	return($self);
}

#--------------------------------------------------------
# 状態保持文字列を生成

sub makeInfoStr {
	my $self = shift;
	
	if ($self->{URL_INFO}) {
		return "/.". $self->{URL_INFO};
	}
}

#=====================================================================
#                        ユーザ情報の取得
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

