package Func::RemoteQueue;

=pod
----------------------------------------------------------------------
�ե�����١����Υ��塼ž����ǽ

�����٤修�����˼㴳�԰¤�����Τǡ�����ƥ�����ʥǡ����ˤϻȤ�ʤ�����

���ºݤ�ž�������� script/daemon/daemon_queue_[send|recv] ��ô��
----------------------------------------------------------------------
=cut

use File::Copy;

use FileHandle;

use strict;
use MobaConf;
use MLog;

#---------------------------------------------------------------------
# queue �񤭽Ф��׵�

sub queue_write {
	my ($queue_file, $queue_data, $host_no) = @_;
	
	$host_no = int($host_no);
	$queue_data =~ s/[\r\n]+//g;
	die if ($queue_file =~ m#/#);
	
	my $fh = new FileHandle;
	if (open($fh, ">>$_::REMOTE_QUEUE_FILE")) {
		print $fh "$host_no\t$queue_file\t$queue_data\n";
		close($fh);
	} else {
		MLog::write(
			"$_::LOG_DIR/queue_write.err",
			"$queue_file\t$queue_data",
			{ no_all_err => 1 });
	}
}

1;
