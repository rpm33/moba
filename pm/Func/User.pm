package Func::User;

use strict;
use MobaConf;
use Kcode;
use Common;

#-----------------------------------------------------------
# 利用機種の更新

sub updateModel {
	my ($user_id, $model_name) = @_;
	
	my $dbh = DA::getHandle($_::DB_USER_W);
	my $sth = $dbh->prepare(<<'SQL');
	update user_data set model_name=? where user_id=?
SQL
	$sth->execute($model_name, $user_id);
}

#-----------------------------------------------------------
# プロフィール表示項目のデータ生成

sub makeProfile {
	my ($rhData) = @_;
	
	if ($rhData->{birthday} =~ /^(\d+)-(\d+)-(\d+)$/ ||
	    $rhData->{birthday} =~ /^(\d{4})(\d\d)(\d\d)$/) {
		my @t1 = (localtime())[5,4,3]; $t1[0] += 1900; $t1[1]++;
		my @t2 = ($1, $2, $3);
		$rhData->{Birthday} = Kcode::e2s(sprintf("%d月%d日", @t2[1, 2]));
		$rhData->{Age} = ($t1[0] - $t2[0]) -
			(($t1[1] * 100 + $t1[2] < $t2[1] * 100 + $t2[2]) ? 1 : 0);
	}
}

#-----------------------------------------------------------
# ハッシュ参照、もしくはハッシュ参照のリストに、ユーザ情報を追加する
# 
# $data : ハッシュ参照 or ハッシュ参照のリスト
# $key  : $data のハッシュ参照で、ユーザIDをあらわすキー名
# $rows : user_data に対する select 文の対象カラム部分

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
