package Request;

=pod
----------------------------------------------------------------------
フォーム送信データのデコード

・送信データは shift jis に変換する。
・各キャリアの絵文字の内部形式への変換もこの時点で行う。
----------------------------------------------------------------------
=cut

use bytes;
use strict;

use MobaConf;
use HTMLFast;
use Common;
use MException;
use FileHandle;
use SoftbankEncode;

# 通常 post

our $POST_MAX_LENGTH   = 100 * 1024; # content-length 最大値 (100KB)
our $POST_READ_TIMEOUT = 5;          # タイムアウト(秒)

# multipart post

our $MP_MAX_LENGTH    = 30 * 1024 * 1024; # content-length 最大値 (30MB)
our $MP_READ_TIMEOUT  = 5;                # タイムアウト(秒) ※read １回あたり
our $MP_READ_BUF_SIZE =  4 * 1024;        # 先読バッファサイズ
our $MP_SAVE_BUF_SIZE = 12 * 1024;        # 全体バッファサイズ

# 変数

our $UPLOAD_DIR   = undef;

# チェック用

our $CODE_SJIS = chr(0x82). chr(0xA0);
our $CODE_UTF8 = chr(0xE3). chr(0x81). chr(0x82);
our $CODE_EUC  = chr(0xA4). chr(0xA2);

sub new {
	my ($pkg, $rhhParam) = @_;
	my $self = {};
	bless($self, $pkg);
	$self->getFormData();
	return($self);
}

sub DESTROY {
	my $self = shift;
	if (ref($self) eq 'HASH' &&
		ref($self->{UPLOAD_FILES}) eq 'ARRAY') {
		
		for my $file (@{$self->{UPLOAD_FILES}}) {
			unlink($file) if (-e $file);
		}
	}
}

#------------------------------------------------------------
# フォームデータの取得

sub getFormData {
	my ($self) = shift;
	
	# 通常パラメータ
	
	if ($ENV{QUERY_STRING}) {
		_decodePairs($self, \$ENV{QUERY_STRING}, '&', '=', '%');
	}
	if ($ENV{REQUEST_METHOD} =~ /^post$/i) {
		if ($ENV{CONTENT_TYPE} =~ m#multipart/form-data#i &&
			$ENV{CONTENT_TYPE} =~ m#boundary=(\S+)#i) {
			$self->processPOST2($1);
		} else {
			$self->processPOST1();
		}
	}
	
	if ($self->{'_CODE'}) {
		if      ($self->{'_CODE'} eq $CODE_SJIS) {
			
		} elsif ($self->{'_CODE'} eq $CODE_UTF8) {
			
			if ($ENV{MB_MODEL_TYPE} eq 'VG') {
				for my $key (keys %{$self}) {
					$self->{$key} =
						SoftbankEncode::utf8_to_sjis($self->{$key});
				}
			} else {
				# モバイルではここにはこない前提
				for my $key (keys %{$self}) {
					Encode::from_to($self->{$key}, 'utf8', 'cp932');
				}
			}
			
		} elsif ($self->{'_CODE'} eq $CODE_EUC) {
			# モバイルではここにもこない前提
			for my $key (keys %{$self}) {
				Encode::from_to($self->{$key}, 'euc-jp', 'cp932');
			}
		
		} else {
			my $tmp = '';
			while ($self->{'_CODE'} =~ /./g) {
				$tmp .= sprintf("%02x", ord($&));
			}
		}
	}
	
	# 絵文字を内部形式（統合形式）に変換
	
	# * といっても、ezweb, imode はコードが被らないので無変換。
	#   softbank は、１文字あたりのバイト数が
	#   1.? 〜5バイトになって扱いにくいため、
	#   1B 24 ** ** 0F を 0B ** ** の１文字３バイトに変換する。
	
	for my $key (keys %{$self}) {
		$self->{$key} = $_::MCODE->any2u($self->{$key});
	}
}

#------------------------------------------------------------

sub processPOST1 {
	my ($self) = @_;
	
	if ($ENV{CONTENT_LENGTH} > $POST_MAX_LENGTH) {
		die "content-length exceed ($ENV{CONTENT_LENGTH})\n";
	}
	
	my ($data, $left) = ('', int($ENV{CONTENT_LENGTH}));
	eval {
		local $SIG{ALRM} = sub { die "TIMEOUT\n" };
		alarm($POST_READ_TIMEOUT);
		while ($left > 0) {
			my $buf;
			my $read = read(STDIN, $buf, $left);
			last if ($read <= 0);
			$left -= $read;
			$data .= $buf;
		}
	};
	alarm(0);
	if ($@ =~ /^TIMEOUT/) {
		MException::error('POST Timeout', {
			Length  => $ENV{CONTENT_LENGTH},
			Content => $data });
	}
	if ($left > 0) {
		MException::error('BrokenRequest', { CODE => 5003,
			Length  => $ENV{CONTENT_LENGTH},
			Content => $data });
	}
	if (!$self->{'.raw'}) {
		_decodePairs($self, \$data, '&', '=', '%');
	}
	$self->{_CONTENT} = $data;
}

#------------------------------------------------------------

sub processPOST2 {
	my ($self, $boundary) = @_;
	
	eval {
		local $SIG{ALRM} = sub { die "TIMEOUT\n" };
		alarm($MP_READ_TIMEOUT);
		$self->_processPOST2($boundary);
	};
	alarm(0);
	
	if ($@) {
		if ($@ =~ /^TIMEOUT/) {
			MException::error('POST Timeout',
				{ Length  => $ENV{CONTENT_LENGTH} });
		} else {
			die "$@\n";
		}
	}
}

sub _processPOST2 {
	my ($self, $boundary) = @_;
	
	if ($ENV{CONTENT_LENGTH} > $MP_MAX_LENGTH) {
		die "content-length exceed ($ENV{CONTENT_LENGTH})\n";
	}
	
	$self->{UPLOAD_FILES} = [];
	
	my $mode = 0;
	my $left = int($ENV{CONTENT_LENGTH});
	
	my $upload_no = 0;
	my ($upload_name, $upload_type, $upload_size, $upload_file);
	my ($name, $buf, $buf_next);
	my $fh = new FileHandle;
	
	while ($left || $buf ne '') {
		
		#---------------
		# データ先読み
		
		if ($left > 0 &&
		    length($buf) < $MP_SAVE_BUF_SIZE - $MP_READ_BUF_SIZE) {
			
			my $len = ($left < $MP_READ_BUF_SIZE)
				? $left : $MP_READ_BUF_SIZE;
			alarm($MP_READ_TIMEOUT);
			if (read(STDIN, $buf_next, $len) <= 0) {
				die "read error\n";
			}
			$left -= length($buf_next);
		}
		
		#---------------
		# 境界チェック
		
		# これだと、\n 改行でデータ末尾が \r の場合 \r がとれてしまうが・・
		
		my $changed = 0;
		my $tmp = $buf. $buf_next;
		if ($tmp =~ /\r?\n?-*$boundary-*\r?\n/m) {
			$buf      = $`;
			$buf_next = $';
			$changed  = 1;
		}
		
		#---------------
		# 読み込みデータ処理
		
		if ($mode == 1) { # ヘッダ待ち
			if ($buf =~ /\r?\n\r?\n/) {
				$buf  = $';
				
				my %header;
				my $headers = $`;
				for my $header (split(/\r?\n/, $headers)) {
					if ($header =~ /^([^:]+):\s*/) {
						$header{lc($1)} = $';
					}
				}
				
				my $filename;
				
				if (my $disposition = $header{'content-disposition'}) {
					$mode = 2;
					for my $part (split(/;\s+/, $disposition)) {
						if ($part =~ /^name="(.*)"/i) {
							$name = $1;
						} elsif ($part =~ /^filename="(.*)"/i) {
							$filename = $1;
							$mode     = 3;
						}
					}
				} else {
					die "$headers\n";
					die "no content-disposition\n";
				}
				
				if ($mode == 3) {
					$upload_no++;
					if ($UPLOAD_DIR eq '') {
						die "not configured for file uploader\n";
					}
					$upload_file = "$UPLOAD_DIR/upload.$$.$upload_no";
					$upload_name = $filename;
					$upload_type = $header{"content-type"};
					$upload_size = 0;
				}
			}
		}
		
		if ($mode == 2) { # データ待ち（ファイル以外）
			if ($buf ne '') {
				$self->{$name} .= $buf;
				$buf = '';
			}
		} elsif ($mode == 3) { # データ待ち（ファイル）
			if ($buf ne '') {
				if ($upload_size == 0) {
					open($fh, ">$upload_file")
						|| die "write error $upload_file\n";
					push(@{$self->{UPLOAD_FILES}}, $upload_file);
				}
				print $fh $buf;
				$upload_size += length($buf);
				$buf = '';
			}
		}
		
		#---------------------
		# 境界処理後だった場合
		
		if ($changed) {
			if ($mode == 3 && $upload_size > 0) {
				close($fh);
				$self->{$name}{'file'} = $upload_file;
				$self->{$name}{'name'} = $upload_name;
				$self->{$name}{'type'} = $upload_type;
				$self->{$name}{'size'} = $upload_size;
			}
			$mode = 1;
		}
		
		if ($buf_next ne '') {
			$buf .= $buf_next;
			$buf_next = '';
		}
	}
	if ($mode == 3 && $upload_size > 0) {
		close($fh);
		$self->{$name}{'file'} = $upload_file;
		$self->{$name}{'name'} = $upload_name;
		$self->{$name}{'type'} = $upload_type;
		$self->{$name}{'size'} = $upload_size;
	}
}

sub _decodePairs {
	my ($rhForm, $rData, $d1, $d2, $d3) = @_;
	foreach (split($d1, ${$rData})) {
		my ($key, $val) = split($d2, $_, -2);
		
		$key = HTMLFast::decode($key, $d3);
		$val = HTMLFast::decode($val, $d3);
		$val =~ s/\r?\n/\n/g;
		unless (defined($rhForm->{$key})) {
			$rhForm->{$key} = $val;
		}
	}
}

#------------------------------------------------------------
# ユーザ認証などの情報を含んだ基本URLを作成

sub makeBasePath {
	my $params = shift;
	
	$params = {} unless (ref($params) eq 'HASH');
	my $host = $params->{host};
	$host = $ENV{MB_REQUIRED_HOST} if ($host eq '');
	$host = $ENV{MB_HTTP_HOST}     if ($host eq '');
	if (ref($_::U) eq 'UserData') {
		return("http://$host". $_::U->makeInfoStr());
	} else {
		return("http://$host");
	}
}

#------------------------------------------------------------
# makeBasePath の SSL ページ版

sub makeSSLBasePath {
	my $params = shift;
	
	return(makeBasePath($params)) if ($_::DEBUG_TEST_SSL);
	
	$params = {} unless (ref($params) eq 'HASH');
	my $host = $params->{host};
	$host = $ENV{MB_REQUIRED_HOST} if ($host eq '');
	$host = $ENV{MB_HTTPS_HOST}    if ($host eq '');
	if (ref($_::U) eq 'UserData') {
		return("https://$host". $_::U->makeInfoStr());
	} else {
		return("https://$host");
	}
}

1;
