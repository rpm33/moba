package DA;

=pod
----------------------------------------------------------------------
DB ハンドルの接続管理モジュール

複数 DB ハンドルの永続接続を管理するために使用。
ひとつのテーブルを複数 DB 分割する場合などは、
対象のハンドルを取得するための関数をここに追加する。
----------------------------------------------------------------------
=cut

use strict;
use DBI;
use MobaConf;
use MException;
use MLog;

our %CONF; # DB 設定（main.conf からセットされる）

our %DBH; # 取得済 DB ハンドル
our %USE; # 使用中 DB ハンドル

our $CONNECT_TIMEOUT = 10;

#-----------------------------------------------------------
# 設定に従ってハンドル取得（ハンドルはキャッシュされる）

# IN:  設定名
# RET: DBハンドル(DBI::db object)

sub getHandle {
	my $name = shift;
	
	if (!$CONF{$name}) {
		MException::error("no database configuration for $name",
			{ CODE => 4001 } );
	}
	
	my $do_connect = 1;
	
	if ($DBH{$name}) {
		$do_connect = 0;
		if (!$USE{$name}) {
			# DA::reset 後、初利用なら接続確認
			if (!$DBH{$name}->ping) {
				$do_connect = 1;
				$DBH{$name}->disconnect();
				delete($DBH{$name});
			}
		}
	}
	if ($do_connect) {
		$DBH{$name} = _connect($name);
	}
	$USE{$name} = 1;
	return($DBH{$name});
}
sub _connect {
	my $name = shift;
	
	my $ac = $CONF{$name}->{TX} ? 0 : 1;
	
	my $dbh = DBI->connect(
		"dbi:mysql:dbname=$CONF{$name}->{DB}".
		";host=$CONF{$name}->{HOST}".
		";mysql_connect_timeout=$CONNECT_TIMEOUT",
		
		"$CONF{$name}->{USER}", "$CONF{$name}->{PASS}",
		{ RaiseError => 1, PrintError => 0, AutoCommit => $ac, Warn => 0 });
	if (!$dbh) {
		MException::error("connect failed",
			{ CODE => 4002, DBIERR => $DBI::err, MSG => $DBI::errstr });
	}
	if (!$ac && $dbh->{AutoCommit}) {
		MException::error("can't set AutoCommit=0",
			{ CODE => 4002, DBIERR => $DBI::err, MSG => $DBI::errstr });
	}
	$dbh->{mysql_auto_reconnect}    = 0;
	$dbh->{mysql_client_found_rows} = 1;
	eval { $dbh->do('set names binary'); };
	
	return $dbh;
}

#-----------------------------------------------------------
# トランザクション開始前に実行

sub reset {
	%USE = ();
}

# 永続接続しているハンドルは、時間経過で切断されている場合がある。
# reset は、このようなハンドルに対して１度だけ再接続を許可する。
# ※トランザクション途中で実行すると、
#   取得済みハンドルが未 commit のまま使用中フラグが落ちてしまうので注意。

#-----------------------------------------------------------
# 接続中の全 DB ハンドルを切断

# 引数で dbh を渡すと、単体での切断も可能

sub disconnect {
	my $tgt_dbh = shift;
	
	my @err;
	for my $name (keys(%USE)) {
		my $dbh = $DBH{$name};
		next if ($tgt_dbh && $tgt_dbh ne $dbh);
		eval {
			$dbh->disconnect();
			delete($DBH{$name});
		};
		push(@err, $name) if ($@);
	}
	if (scalar(@err)) {
		die "error: ". join(',', @err);
	}
	%USE = ();
}

#-----------------------------------------------------------
# 接続中の全 DB ハンドルを切断（RELEASE フラグ付のみ）

sub release {
	my $tgt_dbh = shift;
	
	my @err;
	for my $name (keys(%USE)) {
		my $dbh = $DBH{$name};
		next unless ($CONF{$name}->{RELEASE});
		eval {
			$dbh->disconnect();
			delete($DBH{$name});
		};
		push(@err, $name) if ($@);
	}
	if (scalar(@err)) {
		die "error: ". join(',', @err);
	}
	%USE = ();
}

#-----------------------------------------------------------
# 接続中の全 DB ハンドルを rollback

sub rollback {
	my @err;
	for my $name (keys(%USE)) {
		my $dbh = $DBH{$name};
		next if (!$dbh || $dbh->{AutoCommit});
		eval {
			$dbh->rollback();
		};
		push(@err, $name) if ($@);
	}
	if (scalar(@err)) {
		MException::error("rollback err: ". join(',', @err),
			{ CODE => 4005, DBIERR => $DBI::err, MSG => $DBI::errstr });
	}
}

#-----------------------------------------------------------
# 接続中の全 DB ハンドルを commit

sub commit {
	
	# commit 対象
	
	my @tgtdb;
	for my $name (sort keys %USE) {
		my $dbh = $DBH{$name};
		next if (!$dbh || $dbh->{AutoCommit});
		push(@tgtdb, $name);
	}
	
	# commit 前に ping
	
	for my $name (@tgtdb) {
		if (!$DBH{$name}->ping) {
			MException::error("commit error: $name",
				{ CODE => 4003, DBIERR => $DBI::err, MSG => $DBI::errstr });
		}
	}
	
	# commit
	
	my %done;
	for my $name (@tgtdb) {
		eval {
			$DBH{$name}->commit();
		};
		if ($@) {
			if (scalar(%done)) {
				my (@list1, @list2);
				for (@tgtdb) {
					if ($done{$_}) {
						push(@list1, $_);
					} else {
						push(@list2, $_);
					}
				}
				MException::error(
					"partial commit error: ".
					join(',', @list1). '/'. join(',', @list2),
					{ CODE => 4004, DBIERR => $DBI::err,
						MSG => $DBI::errstr });
			} else {
				MException::error(
					"commit error: $name",
					{ CODE => 4003, DBIERR => $DBI::err,
						MSG => $DBI::errstr });
			}
		} else {
			$done{$name} = 1;
		}
	}
}

#-----------------------------------------------------------
# 指定名のシーケンスを取得

sub getSequence {
	my $dbh = getHandle($_::DB_SEQ);
	my $sth = $dbh->prepare_cached(<<"SQL");
	update seq_$_[0] set id=LAST_INSERT_ID(id+1)
SQL
	$sth->execute();
	return($dbh->{'mysql_insertid'});
}

1;
