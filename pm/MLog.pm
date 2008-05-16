package MLog;

=pod
----------------------------------------------------------------------
ログ記録モジュール
----------------------------------------------------------------------
=cut

use FileHandle;

use strict;
use MobaConf;
use Func::RemoteQueue;

#---------------------------------------
# ローカルログ保存

# $file.log.YYYYMMDD にログを追記。
# *.err というファイル名のログは、ひとつのサーバに転送する。

sub write {
	my ($file, $msg, $params) = @_;
	my @t = localtime(); $t[5] += 1900; $t[4]++;
	my $time  = sprintf("%04d/%02d/%02d %02d:%02d:%02d", @t[5,4,3,2,1,0]);
	my $ymd   = sprintf("%04d%02d%02d", @t[5,4,3]);
	
	$msg =~ s/\\/\\\\/g;
	$msg =~ s/\r/\\r/g;
	$msg =~ s/\n/\\n/g;
	
	my $fh = new FileHandle;
	if ($file && open($fh, ">>$file.log.$ymd")) {
		print $fh "$time\t$msg\n";
		close($fh);
	} else {
		print STDERR "$time\t$msg\n";
	}
	
	# all.err.log に転送
	
	if ($file =~ /\.err$/ && !$params->{no_all_err}) {
		my $log_dir = quotemeta($_::LOG_DIR);
		if ($file =~ m#^$log_dir/?(.*)#) {
			my $name = $1;
			Func::RemoteQueue::queue_write(
				"log:all.err.log.$ymd",
				"$time\tFILE=$_::HOST:$name\t$msg");
		}
	}
}

#---------------------------------------
# リモートログ保存

sub remote {
	my ($file, $msg) = @_;
	
	my @t = localtime(); $t[5] += 1900; $t[4]++;
	my $now = sprintf("%04d/%02d/%02d %02d:%02d:%02d", @t[5,4,3,2,1,0]);
	my $ymd = sprintf("%04d%02d%02d", @t[5,4,3]);
	
	$file =~ s#^$_::LOG_DIR/##;
	
	Func::RemoteQueue::queue_write(
		"log:${file}.log.$ymd",
		join("\t", $now, $_::HOST, $msg));
}

1;
