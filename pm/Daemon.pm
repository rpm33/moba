package Daemon;

=pod
----------------------------------------------------------------------
デーモンスクリプトを簡単に作るためのモジュール

スクリプトで下記をコールすると
start, stop, restart, status ができる daemon として動作する。

Daemon::exec(\&main_function, [\&begin_function], [\&end_function]);

 main_function: メインループ内部に相当する関数
begin_function: 定義されていた場合、デーモン起動時に実行される。（optional）
  end_function: 定義されていた場合、デーモン終了時に実行される。（optional）

子プロセスを作るタイプの daemon は実装例を参考に。
----------------------------------------------------------------------
=cut

use strict;
use warnings;

use FileHandle;
use File::Basename;
use Time::HiRes;
use POSIX 'setsid';
use POSIX ":sys_wait_h";
use Fcntl qw(:flock);

use MobaConf;
use DA;

our $NAME           = '';  # daemon 名
our $PID_FILE       = '';  # pid 管理ファイル
our $CHK_FILE       = '';  # 必須稼動ID指定ファイル
our $MAIN_PID       = 0;   # メインループプロセスのPID
our $LAST_CHK_TIME  = 0;   # 最後に自己停止チェック時刻
our $ID             = 'M'; # M:親プロセス -:子プロセス(IDなし) 他:子プロセス
our %CHILDREN       = ();  # 子プロセス管理ハッシュテーブル

our $TERM_FLG       = 0;   # 1:終了
our $LAST_HEARTBEAT = 0;   # heartbeat 最終更新日時

our $VERSION = '0.01';

######################################################################
# 
#                    daemon コマンドライン処理
# 
######################################################################

#-----------------------------------------------------------
# コマンドライン処理エントリポイント

sub exec {
	my ($rfMain, $rfBegin, $rfEnd) = @_;
	
	die "RUN_DIR not defined\n"            if (!   $_::RUN_DIR);
	die "RUN_DIR ($_::RUN_DIR) not exists" if (!-d $_::RUN_DIR);
	
	$NAME     = basename($0);
	$PID_FILE = "$_::RUN_DIR/$NAME.pid";
	$CHK_FILE = "$_::RUN_DIR/$NAME.chk";
	
	my $cmd = shift(@ARGV);
	$cmd .= '';
	
	if (!$Daemon::CONF{$NAME}) {
		print "Not configured\n";
		return(-1);
	}
	
	my $res = 0;
	if ($cmd eq 'start') {
		$res = start();
	} elsif ($cmd eq 'stop') {
		$res = stop();
	} elsif ($cmd eq 'status') {
		$res = status();
	} elsif ($cmd eq 'restart') {
		stop();
		$res = start();
	} elsif ($cmd eq 'condrestart') {
		if ($res = stop()) {
			$res = start();
		}
	} elsif ($cmd eq 'daemon') {
		daemon($rfMain, $rfBegin, $rfEnd);
	} else {
		print "Usage: $NAME start [options]| stop | [cond]restart | status\n";
	}
	exit($res);
}

#-----------------------------------------------------------
# 開始コマンド

sub start {
	my $pid = _get_pid('M');
	
	
	if ($pid && -e "/proc/$pid") {
		printf("%-23s already running\n", $NAME);
		return(0);
	}
	my $fh = new FileHandle;
	open($fh, ">$PID_FILE");
	close($fh);
	
	my $args = join(' ', map { qq|"$_"| } @ARGV);
	system("nice $0 daemon $args &");
	print "Start $NAME\n";
	return(1);
}

#-----------------------------------------------------------
# 終了コマンド

sub stop {
	my $pid = _get_pid('M');
	if (!$pid || !-e "/proc/$pid") {
		printf("%-23s not running\n", $NAME);
		return(0);
	}
	system("kill -TERM $pid");
	
	while (-e "/proc/$pid") { Time::HiRes::sleep(0.1); }
	
	print "Stop  $NAME\n";
	return(1);
}

#-----------------------------------------------------------
# 状態確認コマンド

sub status {
	
	# チェック対象 pid の取得
	
	my (%check, %id2pid);
	
	my $fh = new FileHandle;
	if (open($fh, $PID_FILE)) {
		flock($fh, LOCK_SH);
		while (<$fh>) {
			chomp;
			my ($pid, $id) = split(/\t/, $_);
			$check{$pid} = $id;
			$id2pid{$id} = $pid;
		}
		close($fh);
	}
	
	# 起動必須ID
	
	{
		my $tmp = 0;
		my %force_id;
		if (open($fh, $CHK_FILE)) {
			while (<$fh>) {
				chomp;
				$force_id{$_} = 1;
			}
			close($fh);
		}
		
		for my $id ('M', keys %force_id) {
			if ($id2pid{$id}) {
				$check{$id2pid{$id}} = $id;
			} else {
				$tmp--;
				$id2pid{$id} = $tmp;
				$check{$tmp} = $id;
			}
		}
	}
	
	# pid リストのソート
	
	my @pids;
	push(@pids, $id2pid{M});
	for my $pid (sort { $check{$a} cmp $check{$b} } keys %check) {
		push(@pids, $pid) if ($check{$pid} ne 'M');
	}
	
	# チェック
	
	my $status = 1;
	for my $pid (@pids) {
		my $id = $check{$pid} ne '' ? $check{$pid} : '-';
		my $name = ($id eq 'M') ? $NAME : "$NAME:$id";
		$name = sprintf("%-22s", $name);
		
		# pid の生存チェック
		
		if (!$pid || !-e "/proc/$pid") {
			print "$name not running (stop)\n";
			$status = 0 if ($status > 0);
			next;
		}
		
		# heartbeat チェック
		
		my $heartbeat = 0;
		# hb ファイルが一瞬空の状態に対応するためリトライ
		for (0..2) {
			my $fh = new FileHandle;
			if (open($fh, "$_::RUN_DIR/$NAME.hb.$pid")) {
				my $line = <$fh>;
				$heartbeat = $1 if ($line =~ /^(\d+|-)/);
				close($fh);
			}
			last if ($heartbeat);
			Time::HiRes::sleep(0.2);
		}
		if ($heartbeat ne '-' && time() - $heartbeat > 60) {
			print "$name not running (hang up?)\n";
			$status = -1 if ($status > -1);
			next;
		} else {
			print "$name running ($pid)\n";
		}
	}
	return $status;
}

#-----------------------------------------------------------
# daemon プロセスコマンド（start コマンドから、内部的にコールされる）

sub daemon {
	my ($rfMain, $rfBegin, $rfEnd) = @_;
	
	_daemonize();
	
	system("rm -f $_::RUN_DIR/$NAME.hb.*");
	
	eval {
		$MAIN_PID = $$;
		
		$SIG{INT}  = sub { $TERM_FLG = 1; };
		$SIG{TERM} = sub { $TERM_FLG = 1; };
		$SIG{CHLD} = \&_on_sigchld;
		
		_add_pid('M');
		
		&{$rfBegin} if ($rfBegin);
		
		# daemon メインループ
		
		while (!$TERM_FLG) {
			update_heartbeat();
			&{$rfMain};
			DA::disconnect();
			check_term();
		}
		_remove_heartbeat();
		_del_pid();
		
		if (is_main()) { # 子プロセスの終了待ち
			for my $pid (keys %CHILDREN) {
				system("kill -TERM $pid");
			}
			while (scalar(keys %CHILDREN)) {
				for my $pid (keys %CHILDREN) {
					my $ret = waitpid($pid, WNOHANG);
					if (!$ret) {
						delete($CHILDREN{$pid});
					}
				}
			}
			unlink($CHK_FILE);
		}
		
		&{$rfEnd} if ($rfEnd);
	};
	if ($@) {
		MLog::write("$_::LOG_DIR/daemon.err", "$NAME\t$@");
	}
}

######################################################################
# 
#                         daemon 補助関数
# 
######################################################################

#-----------------------------------------------------------
# 子プロセスを作る際に使用。子プロセス毎に異なる id を指定
# 
# * メインループを使わない子プロセスの場合、
#   子プロセス完了時に finish_fork をコールすること。

sub safe_fork {
	my ($id) = @_;
	
	DA::disconnect();
	
	if (my $pid_c = fork()) { # 親プロセス
		$CHILDREN{$pid_c} = $id;
		return $pid_c;
	} else { # 子プロセス
		$ID = $id;
		_add_pid($id);
		update_heartbeat();
		return 0;
	}
}

#-----------------------------------------------------------
# fork の終了（daemon ループを使う場合は、自動処理されるのでコール不要）

sub finish_fork {
	_remove_heartbeat();
	_del_pid();
	exit;
}

#-----------------------------------------------------------
# 自分がメイン(親)プロセスだったら true

sub is_main {
	return ($$ == $MAIN_PID) ? 1 : 0;
}

#-----------------------------------------------------------
# 終了状態か？

sub is_term {
	return $TERM_FLG ? 1 : 0;
}

#-----------------------------------------------------------
# 稼動確認データの更新
# 
#（通常はメインループが１回終わる度に
#  自動でコールされるので明示的にコールする必要はない。
#  １回のループが長時間かかる場合は適宜コールする。）

sub update_heartbeat {
	my  $now = Time::HiRes::time();
	
	return if ($now < $LAST_HEARTBEAT + 1);
	
	$LAST_HEARTBEAT = $now;
	
	my $fh = new FileHandle;
	
	# 無視指定されていたら更新しない
	
	if (open($fh, "$_::RUN_DIR/$NAME.hb.$$")) {
		my $hb = <$fh>; chomp($hb);
		close($fh);
		return if ($hb eq '-');
	}
	
	if (open($fh, ">$_::RUN_DIR/$NAME.hb.$$")) {
		print $fh time();
		close($fh);
	}
}

#-----------------------------------------------------------
# 稼動確認データ無視指定

# * update_heartbeat を定期的にコールすることが難しい場合に使用

sub disable_heartbeat {
	my $fh = new FileHandle;
	if (open($fh, ">$_::RUN_DIR/$NAME.hb.$$")) {
		print $fh '-';
		close($fh);
	}
}

#-----------------------------------------------------------
# disable_heartbeat 解除

sub enable_heartbeat {
	my $fh = new FileHandle;
	if (open($fh, ">$_::RUN_DIR/$NAME.hb.$$")) {
		print $fh time();
		close($fh);
	}
}

#-----------------------------------------------------------
# 稼動必須ID（子プロセス）のセット

sub set_chk_ids {
	my @ids = @_;
	
	my $fh = new FileHandle;
	open($fh, ">$CHK_FILE") || die;
	print $fh join('', map { "$_\n" } @ids);
	close($fh);
}

#-----------------------------------------------------------
# 自分が動作すべき状態かチェック

# （前回のチェックから１秒以上経過してなかったらチェックしない）

sub check_term {
	my $now = Time::HiRes::time();
	if ($now > $LAST_CHK_TIME + 1) {
		
		# 親プロセスが死んでいたら終了
		
		if (!-e "/proc/$MAIN_PID") {
			$TERM_FLG = 1; return;
		}
		
		# 稼動ファイルの状態と現状がずれていたら終了
		
		my $pid = _get_pid('M');
		if (!$pid || $pid ne $MAIN_PID) {
			$TERM_FLG = 1; return;
		}
		my $id = _chk_pid();
		if ($id ne $ID) {
			$TERM_FLG = 1; return;
		}
	}
}

#-----------------------------------------------------------
# TERM_FLG 対応 sleep

# * 普通に sleep してもよいが、終了処理の待ち時間が長くなるのでこちらを推奨

sub sleep2 {
	my $sleep = shift;
	my $until = Time::HiRes::time() + $sleep;
	while      (Time::HiRes::time() < $until && !$TERM_FLG) {
		Time::HiRes::sleep(0.1);
	}
}

######################################################################
# 
#                       daemon ローカル関数
# 
######################################################################

#-----------------------------------------------------------
# 一般的な daemon 化処理

sub _daemonize {
	defined(my $pid = fork())
		|| die "Can't fork: $!";
	exit if ($pid);
	setsid()
		|| die "Can't start a new session: $!";
	chdir('/')
		|| die "Can't chdir to /: $!";
	umask(0)
		|| die "Can't set umask to 0: $!";
	close(STDIN)
		|| die "Can't close STDIN: $!";
	close(STDOUT)
		|| die "Can't close STDOUT: $!";
	close(STDERR)
		|| die "Can't close STDERR: $!";
	open(STDIN, '/dev/null')
		|| die "Can't open /dev/null: $!";
	open(STDOUT, '>/dev/null')
		|| die "Can't open /dev/null: $!";
	open(STDERR, '>&STDOUT')
		|| die "Can't dup stdout: $!";
	
	$SIG{ALRM} = 'IGNORE';
	$SIG{HUP}  = 'IGNORE';
	$SIG{PIPE} = 'IGNORE';
	$SIG{TERM} = 'IGNORE';
}

#-----------------------------------------------------------
# 自分の pid を登録

sub _add_pid {
	my ($add_id) = @_;
	
	my $fh = new FileHandle;
	open($fh, "+<$PID_FILE") || die;
	flock($fh, LOCK_EX);
	
	my $data = '';
	while (<$fh>) {
		chomp;
		my ($pid, $id) = split(/\t/, $_);
		if ($pid == $$ || ($id eq $add_id && $id ne '-')) {
			close($fh);
			die;
		}
		$data .= "$pid\t$id\n";
	}
	$data .= "$$\t$add_id\n";
	
	truncate($fh, 0);
	seek($fh, 0, 0);
	print $fh $data;
	close($fh);
}

#-----------------------------------------------------------
# 自分の pid を削除

sub _del_pid {
	my $fh = new FileHandle;
	
	open($fh, "+<$PID_FILE") || die;
	flock($fh, LOCK_EX);
	
	my $data = '';
	while (<$fh>) {
		chomp;
		my ($pid, $id) = split(/\t/, $_);
		$data .= "$pid\t$id\n" if ($pid != $$);
	}
	
	truncate($fh, 0);
	seek($fh, 0, 0);
	print $fh $data;
	close($fh);
	
	if ($data eq '') {
		unlink($PID_FILE);
	}
}

#-----------------------------------------------------------
# 指定IDの pid を取得

sub _get_pid {
	my ($tgt_id) = @_;
	
	my $fh = new FileHandle;
	open($fh, $PID_FILE) || return undef;
	flock($fh, LOCK_SH);
	while (<$fh>) {
		chomp;
		my ($pid, $id) = split(/\t/, $_);
		if ($tgt_id eq $id) {
			close($fh);
			return $pid;
		}
	}
	close($fh);
	return undef;
}

#-----------------------------------------------------------
# 自分の pid の動作 ID を取得

sub _chk_pid {
	my $fh = new FileHandle;
	open($fh, $PID_FILE) || return undef;
	flock($fh, LOCK_SH);
	while (<$fh>) {
		chomp;
		my ($pid, $id) = split(/\t/, $_);
		if ($pid == $$) {
			close($fh);
			return $id;
		}
	}
	close($fh);
	return undef;
}

#-----------------------------------------------------------
# 稼動確認データファイルの削除

sub _remove_heartbeat {
	unlink("$_::RUN_DIR/$NAME.hb.$$");
}

#-----------------------------------------------------------
# 子プロセス終了時の処理（メインループプロセス用）

sub _on_sigchld {
	return unless (is_main());
	
	for my $pid (keys %CHILDREN) {
		my $ret = waitpid($pid, WNOHANG);
		if ($ret == $pid) {
			delete($CHILDREN{$pid});
		}
	}
}

#-----------------------------------------------------------

1;

