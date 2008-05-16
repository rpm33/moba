package Func::User;

use strict;
use MobaConf;
use Kcode;
use Common;

#-----------------------------------------------------------
# ���ѵ���ι���

sub updateModel {
	my ($user_id, $model_name) = @_;
	
	my $dbh = DA::getHandle($_::DB_USER_W);
	my $sth = $dbh->prepare(<<'SQL');
	update user_data set model_name=? where user_id=?
SQL
	$sth->execute($model_name, $user_id);
}

#-----------------------------------------------------------
# �ץ�ե�����ɽ�����ܤΥǡ�������

sub makeProfile {
	my ($rhData) = @_;
	
	if ($rhData->{birthday} =~ /^(\d+)-(\d+)-(\d+)$/ ||
	    $rhData->{birthday} =~ /^(\d{4})(\d\d)(\d\d)$/) {
		my @t1 = (localtime())[5,4,3]; $t1[0] += 1900; $t1[1]++;
		my @t2 = ($1, $2, $3);
		$rhData->{Birthday} = Kcode::e2s(sprintf("%d��%d��", @t2[1, 2]));
		$rhData->{Age} = ($t1[0] - $t2[0]) -
			(($t1[1] * 100 + $t1[2] < $t2[1] * 100 + $t2[2]) ? 1 : 0);
	}
}

#-----------------------------------------------------------
# �ϥå��廲�ȡ��⤷���ϥϥå��廲�ȤΥꥹ�Ȥˡ��桼��������ɲä���
# 
# $data : �ϥå��廲�� or �ϥå��廲�ȤΥꥹ��
# $key  : $data �Υϥå��廲�Ȥǡ��桼��ID�򤢤�魯����̾
# $rows : user_data ���Ф��� select ʸ���оݥ������ʬ

sub addUserInfo {
	my ($data, $key, $rows) = @_;
	
	my $rList = [];
	if (ref($data) eq 'HASH') {
		push(@{$rList}, $data);
	} elsif (ref($data) eq 'ARRAY') {
		$rList = $data;
	} else {
		return;
	}
	
	my @user_ids;
	for my $rHash (@{$rList}) {
		if (ref($rHash) eq 'HASH' &&
		    exists($rHash->{$key})) {
			push(@user_ids, int($rHash->{$key}));
		}
	}
	
	my $ids = join(',', 0, @user_ids);
	
	my $dbh = DA::getHandle($_::DB_USER_R);
	my $ret = $dbh->selectall_hashref(<<"SQL", '_u');
	select user_id _u, $rows from user_data where user_id in ($ids);
SQL
	for my $rHash (@{$rList}) {
		if (ref($rHash) eq 'HASH' &&
		    exists($rHash->{$key}) &&
			exists($ret->{$rHash->{$key}})) {
			
			Common::mergeHash($rHash, $ret->{$rHash->{$key}}, '^[^_]');
		}
	}
}


1;
