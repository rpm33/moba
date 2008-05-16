package MException;

=pod
----------------------------------------------------------------------
例外処理関係

下記の使用方法が基本。

eval {
	MException::error("error message", { CODE => 1234 });
};
if ($@) {
	my $e   = MException::getInfo();
	my $msg = MException::makeMsg($e);
}

エラーコードのマスタは特にない。

4001: DB 設定エラー
4002: DB 接続エラー
4003: DB commit エラー
4004: DB commit エラー（部分コミット）
4005: DB rollback エラー
5003: POST リクエスト読み込みエラー

特定エラーの監視をするために作ったが、
結局エラーメッセージで監視したほうがシンプルなので、
最近はエラー時は単純に die するほうが多く、無理して使う必要はない。

MException::throw のほうは、リダイレクトや function 変更などで使っている。
----------------------------------------------------------------------
=cut

use FileHandle;

my $gInfo; # 直近の例外情報

my %conv = (
"\r" => '%0D',
"\n" => "%0A",
"\t" => "%09",
"%"  => "%25",
);

#-----------------------------------------------------------
# エラー通知

# $msg:     エラーメッセージ
# $rParams: パラメータハッシュリファレンス(*1)
# 
# (*1) 何を渡すかは任意

sub error {
	my ($msg, $rParams) = @_;
	if ($rParams) {
		$gInfo = $rParams;
	} else {
		$gInfo = {};
	}
	$gInfo->{_T}  = 'ERR';
	$gInfo->{MSG} = $msg;
	
	if (!exists($gInfo->{_P})) {
		($gInfo->{_P}, $gInfo->{_F}, $gInfo->{_L}) = caller;
	}
	
	die "Exception\n";
}

#-----------------------------------------------------------
# 例外 throw

# 第一引数: パラメータハッシュリファレンス(*1)
# 
# (*1) 何を渡すかは任意だが、下記パラメータは Page/Main.pm で
#      catch されて、固有の動作を行う。
# 
#    CHG_FUNC  => 'func_name' : 別の function に内部的にリダイレクト
#    REDIRECT  => 'url'       : 指定 url にリダイレクトさせる
#    REDIRECT2 => 1           : 正しい url にリダイレクト

sub throw {
	$gInfo = shift;
	
	if (!exists($gInfo->{_P})) {
		($gInfo->{_P}, $gInfo->{_F}, $gInfo->{_L}) = caller;
	}
	die "Exception\n";
}

#-----------------------------------------------------------
# 例外情報を文字列化

sub makeMsg {
	my $rHash = shift;
	my $msg = '';
	
	if (!$rHash->{_LITE}) {
		if ($rHash->{_P}) {
			$msg = "$rHash->{_P}:$rHash->{_F}:$rHash->{_L}\t";
		} else {
			my @caller = caller;
			$msg = "$caller[0]:$caller[1]:$caller[2]\t";
		}
	}
	
	for my $key (sort keys(%{$rHash})) {
		next if ($key =~ /^_/);
		my $val = $rHash->{$key};
		$val =~ s/[\r\n\t\%]/$conv{$&}/g;
		if ($msg) {
			$msg .= "\t$key:$val";
		} else {
			$msg = "$key:$val";
		}
	}
	
	return($msg);
}

#-----------------------------------------------------------
# 直近の例外情報を取得。

# 普通に die した場合も例外情報のかたちに変換する。

sub getInfo {
	my $msg = $@;
	$@ = undef;
	return($gInfo) if ($msg eq "Exception\n");
	
	$gInfo = {};
	$gInfo->{_T}  = 'ERR';
	$gInfo->{_P}  = '-';
	$gInfo->{_F}  = '-';
	$gInfo->{_L}  = '-';
	$gInfo->{MSG} = $msg;
	$gInfo->{MSG} =~ s/\n$//;
	return($gInfo);
}

1;
