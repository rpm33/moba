package Func::RemoteQueue;

=pod
----------------------------------------------------------------------
ファイルベースのキュー転送機能

安定度や信頼性に若干不安があるので、クリティカルなデータには使わないこと

※実際の転送処理は script/daemon/daemon_queue_[send|recv] が担当
----------------------------------------------------------------------
=cut

use File::Copy;

use FileHandle;

use strict;
use MobaConf;
use MLog;

#---------------------------------------------------------------------
# queue 書き出し要求

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
