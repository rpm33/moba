package Common;

=pod
----------------------------------------------------------------------
ユーティリティー系の共通処理を入れるモジュール

軽めな処理はここに入れる
----------------------------------------------------------------------
=cut

use strict;
use HTMLFast;

our $CHARS =
	'0123456789'.
	'abcdefghijklmnopqrstuvwxyz'.
	'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

#-----------------------------------------------------------
# 指定長のランダム文字列を作成

sub makeRandomString {
	my $len = shift;
	my $l = length($CHARS);
	my $str;
	for (1..$len) {
		$str .= substr($CHARS, int(rand($l)), 1);
	}
	return($str);
}

#-----------------------------------------------------------
# 与えられたハッシュリファレンスを hidden タグのリストにする

sub makeHidden {
	my ($rhParams) = @_;
	my $ret = '';
	for my $k (keys(%{$rhParams})) {
		my $key = HTMLFast::htmlspecialchars($k);
		my $val = HTMLFast::htmlspecialchars($rhParams->{$k});
		$ret .= qq|<input type="hidden" name="$key" value="$val">\n|;
	}
	return($ret);
}

#------------------------------------------------------------
# 与えられたハッシュリファレンスを QUERY_STRING 形式にする

# option: $d1, $d2, $d3 を指定することで、別のエンコード方法も使える。

sub makeParams {
	my ($rhParams, $d1, $d2, $d3) = @_;
	my @qs;
	
	$d1 = '&' if (!$d1);
	$d2 = '=' if (!$d2);
	$d3 = '%' if (!$d3);
	
	for my $key (sort keys(%{$rhParams})) {
		my $val = $rhParams->{$key};
		next if ($val eq '' || $key eq 'f');
		my $key  = HTMLFast::encode($key, $d3);
		my $val  = HTMLFast::encode($val, $d3);
		
		push(@qs, "$key$d2$val");
	}
	return(join($d1, @qs));
}

#-----------------------------------------------------------
# ハッシュを複製する

# 入力: $rHash: ハッシュリファレンス
#       $match: この正規表現にマッチするキーのみ複製 (option)
# 出力: ハッシュリファレンス

sub cloneHash {
	my ($rHash, $match) = @_;
	my %newHash;
	
	if ($match) {
		for my $key (keys(%{$rHash})) {
			if ($key =~ /$match/) {
				$newHash{$key} = $rHash->{$key};
			}
		}
	} else {
		for my $key (keys(%{$rHash})) {
			$newHash{$key} = $rHash->{$key};
		}
	}
	
	return(\%newHash);
}

#-----------------------------------------------------------
# ハッシュをマージする

# 入力: $rDstHash: マージ先ハッシュリファレンス
#       $rSrcHash: マージ元ハッシュリファレンス
#       $match: この正規表現にマッチするキーのみマージ (option)

sub mergeHash {
	my ($rDstHash, $rSrcHash, $match) = @_;
	
	if ($match) {
		for my $key (keys(%{$rSrcHash})) {
			if ($key =~ /$match/) {
				$rDstHash->{$key} = $rSrcHash->{$key};
			}
		}
	} else {
		for my $key (keys(%{$rSrcHash})) {
			$rDstHash->{$key} = $rSrcHash->{$key};
		}
	}
}


1;
