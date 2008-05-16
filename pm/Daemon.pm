package Daemon;

=pod
----------------------------------------------------------------------
�ǡ���󥹥���ץȤ��ñ�˺�뤿��Υ⥸�塼��

������ץȤǲ����򥳡��뤹���
start, stop, restart, status ���Ǥ��� daemon �Ȥ���ư��롣

Daemon::exec(\&main_function, [\&begin_function], [\&end_function]);

 main_function: �ᥤ��롼����������������ؿ�
begin_function: �������Ƥ�����硢�ǡ����ư���˼¹Ԥ���롣��optional��
  end_function: �������Ƥ�����硢�ǡ����λ���˼¹Ԥ���롣��optional��

�ҥץ������륿���פ� daemon �ϼ�����򻲹ͤˡ�
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

our $NAME           = '';  # daemon ̾
our $PID_FILE       = '';  # pid �����ե�����
our $CHK_FILE       = '';  # ɬ�ܲ�ưID����ե�����
our $MAIN_PID       = 0;   # �ᥤ��롼�ץץ�����PID
our $LAST_CHK_TIME  = 0;   # �Ǹ�˼�����ߥ����å�����
our $ID             = 'M'; # M:�ƥץ��� -:�ҥץ���(ID�ʤ�) ¾:�ҥץ���
our %CHILDREN       = ();  # �ҥץ��������ϥå���ơ��֥�

our $TERM_FLG       = 0;   # 1:��λ
our $LAST_HEARTBEAT = 0;   # heartbeat �ǽ���������

our $VERSION = '0.01';

######################################################################
# 
#                    daemon ���ޥ�ɥ饤�����
# 
######################################################################

#-----------------------------------------------------------
# ���ޥ�ɥ饤���������ȥ�ݥ����

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
# ���ϥ��ޥ��

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
# ��λ���ޥ��

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
# ���ֳ�ǧ���ޥ��

sub status {
	
	# �����å��о� pid �μ���
	
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
	
	# ��ưɬ��ID
	
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
	
	# pid �ꥹ�ȤΥ�����
	
	my @pids;
	push(@pids, $id2pid{M});
	for my $pid (sort { $check{$a} cmp $check{$b} } keys %check) {
		push(@pids, $pid) if ($check{$pid} ne 'M');
	}
	
	# �����å�
	
	my $status = 1;
	for my $pid (@pids) {
		my $id = $check{$pid} ne '' ? $check{$pid} : '-';
		my $name = ($id eq 'M') ? $NAME : "$NAME:$id";
		$name = sprintf("%-22s", $name);
		
		# pid ����¸�����å�
		
		if (!$pid || !-e "/proc/$pid") {
			print "$name not running (stop)\n";
			$status = 0 if ($status > 0);
			next;
		}
		
		# heartbeat �����å�
		
		my $heartbeat = 0;
		# hb �ե����뤬��ֶ��ξ��֤��б����뤿���ȥ饤
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
# daemon �ץ������ޥ�ɡ�start ���ޥ�ɤ��顢����Ū�˥����뤵����

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
		
		# daemon �ᥤ��롼��
		
		while (!$TERM_FLG) {
			update_heartbeat();
			&{$rfMain};
			DA::disconnect();
			check_term();
		}
		_remove_heartbeat();
		_del_pid();
		
		if (is_main()) { # �ҥץ����ν�λ�Ԥ�
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
#                         daemon ����ؿ�
# 
######################################################################

#-----------------------------------------------------------
# �ҥץ�������ݤ˻��ѡ��ҥץ�����˰ۤʤ� id �����
# 
# * �ᥤ��롼�פ�Ȥ�ʤ��ҥץ����ξ�硢
#   �ҥץ�����λ���� finish_fork �򥳡��뤹�뤳�ȡ�

sub safe_fork {
	my ($id) = @_;
	
	DA::disconnect();
	
	if (my $pid_c = fork()) { # �ƥץ���
		$CHILDREN{$pid_c} = $id;
		return $pid_c;
	} else { # �ҥץ���
		$ID = $id;
		_add_pid($id);
		update_heartbeat();
		return 0;
	}
}

#-----------------------------------------------------------
# fork �ν�λ��daemon �롼�פ�Ȥ����ϡ���ư���������Τǥ��������ס�

sub finish_fork {
	_remove_heartbeat();
	_del_pid();
	exit;
}

#-----------------------------------------------------------
# ��ʬ���ᥤ��(��)�ץ������ä��� true

sub is_main {
	return ($$ == $MAIN_PID) ? 1 : 0;
}

#-----------------------------------------------------------
# ��λ���֤���

sub is_term {
	return $TERM_FLG ? 1 : 0;
}

#-----------------------------------------------------------
# ��ư��ǧ�ǡ����ι���
# 
#���̾�ϥᥤ��롼�פ����󽪤���٤�
#  ��ư�ǥ����뤵���Τ�����Ū�˥����뤹��ɬ�פϤʤ���
#  ����Υ롼�פ�Ĺ���֤��������Ŭ�������뤹�롣��

sub update_heartbeat {
	my  $now = Time::HiRes::time();
	
	return if ($now < $LAST_HEARTBEAT + 1);
	
	$LAST_HEARTBEAT = $now;
	
	my $fh = new FileHandle;
	
	# ̵����ꤵ��Ƥ����鹹�����ʤ�
	
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
# ��ư��ǧ�ǡ���̵�����

# * update_heartbeat �����Ū�˥����뤹�뤳�Ȥ��񤷤����˻���

sub disable_heartbeat {
	my $fh = new FileHandle;
	if (open($fh, ">$_::RUN_DIR/$NAME.hb.$$")) {
		print $fh '-';
		close($fh);
	}
}

#-----------------------------------------------------------
# disable_heartbeat ���

sub enable_heartbeat {
	my $fh = new FileHandle;
	if (open($fh, ">$_::RUN_DIR/$NAME.hb.$$")) {
		print $fh time();
		close($fh);
	}
}

#-----------------------------------------------------------
# ��ưɬ��ID�ʻҥץ����ˤΥ��å�

sub set_chk_ids {
	my @ids = @_;
	
	my $fh = new FileHandle;
	open($fh, ">$CHK_FILE") || die;
	print $fh join('', map { "$_\n" } @ids);
	close($fh);
}

#-----------------------------------------------------------
# ��ʬ��ư��٤����֤������å�

# ������Υ����å����飱�ðʾ�вᤷ�Ƥʤ��ä�������å����ʤ���

sub check_term {
	my $now = Time::HiRes::time();
	if ($now > $LAST_CHK_TIME + 1) {
		
		# �ƥץ��������Ǥ����齪λ
		
		if (!-e "/proc/$MAIN_PID") {
			$TERM_FLG = 1; return;
		}
		
		# ��ư�ե�����ξ��֤ȸ���������Ƥ����齪λ
		
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
# TERM_FLG �б� sleep

# * ���̤� sleep ���Ƥ�褤������λ�������Ԥ����֤�Ĺ���ʤ�ΤǤ������侩

sub sleep2 {
	my $sleep = shift;
	my $until = Time::HiRes::time() + $sleep;
	while      (Time::HiRes::time() < $until && !$TERM_FLG) {
		Time::HiRes::sleep(0.1);
	}
}

######################################################################
# 
#                       daemon ������ؿ�
# 
######################################################################

#-----------------------------------------------------------
# ����Ū�� daemon ������

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
# ��ʬ�� pid ����Ͽ

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
# ��ʬ�� pid ����

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
# ����ID�� pid �����

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
# ��ʬ�� pid ��ư�� ID �����

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
# ��ư��ǧ�ǡ����ե�����κ��

sub _remove_heartbeat {
	unlink("$_::RUN_DIR/$NAME.hb.$$");
}

#-----------------------------------------------------------
# �ҥץ�����λ���ν����ʥᥤ��롼�ץץ����ѡ�

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

