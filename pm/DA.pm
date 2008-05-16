package DA;

=pod
----------------------------------------------------------------------
DB �ϥ�ɥ����³�����⥸�塼��

ʣ�� DB �ϥ�ɥ�α�³��³��������뤿��˻��ѡ�
�ҤȤĤΥơ��֥��ʣ�� DB ʬ�䤹����ʤɤϡ�
�оݤΥϥ�ɥ��������뤿��δؿ��򤳤����ɲä��롣
----------------------------------------------------------------------
=cut

use strict;
use DBI;
use MobaConf;
use MException;
use MLog;

our %CONF; # DB �����main.conf ���饻�åȤ�����

our %DBH; # ������ DB �ϥ�ɥ�
our %USE; # ������ DB �ϥ�ɥ�

our $CONNECT_TIMEOUT = 10;

#-----------------------------------------------------------
# ����˽��äƥϥ�ɥ�����ʥϥ�ɥ�ϥ���å��夵����

# IN:  ����̾
# RET: DB�ϥ�ɥ�(DBI::db object)

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
			# DA::reset �塢�����Ѥʤ���³��ǧ
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
# �ȥ�󥶥�����󳫻����˼¹�

sub reset {
	%USE = ();
}

# ��³��³���Ƥ���ϥ�ɥ�ϡ����ַв�����Ǥ���Ƥ����礬���롣
# reset �ϡ����Τ褦�ʥϥ�ɥ���Ф��ƣ��٤�������³����Ĥ��롣
# ���ȥ�󥶥����������Ǽ¹Ԥ���ȡ�
#   �����Ѥߥϥ�ɥ뤬̤ commit �Τޤ޻�����ե饰������Ƥ��ޤ��Τ���ա�

#-----------------------------------------------------------
# ��³����� DB �ϥ�ɥ������

# ������ dbh ���Ϥ��ȡ�ñ�ΤǤ����Ǥ��ǽ

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
# ��³����� DB �ϥ�ɥ�����ǡ�RELEASE �ե饰�դΤߡ�

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
# ��³����� DB �ϥ�ɥ�� rollback

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
# ��³����� DB �ϥ�ɥ�� commit

sub commit {
	
	# commit �о�
	
	my @tgtdb;
	for my $name (sort keys %USE) {
		my $dbh = $DBH{$name};
		next if (!$dbh || $dbh->{AutoCommit});
		push(@tgtdb, $name);
	}
	
	# commit ���� ping
	
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
# ����̾�Υ������󥹤����

sub getSequence {
	my $dbh = getHandle($_::DB_SEQ);
	my $sth = $dbh->prepare_cached(<<"SQL");
	update seq_$_[0] set id=LAST_INSERT_ID(id+1)
SQL
	$sth->execute();
	return($dbh->{'mysql_insertid'});
}

1;
