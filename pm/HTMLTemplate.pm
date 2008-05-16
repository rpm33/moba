package HTMLTemplate;

=pod
----------------------------------------------------------------------
モバイル用HTMLテンプレート処理（MTemplate への wrapper）

MTemplate.pm に渡す共通パラメータを設定する。
必要に応じてパラメータは追加していくこと。
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;
use MTemplate;

# small タグ（キャリアデフォルト）

our %SMALL_TAG_C = (
'D' => '<span style="font-size:smaller">',
'A' => '<font size="1">',
'V' => '<font style="font-size:15px">',
);

# small タグ（個別機種）

# ↓au は 12 px フォントを表示させたいときの指定方法が
#   機種によってまちまちなため個別設定で対応。以下はその一例。

our %SMALL_TAG_M = (
'CA31' => '<font style="font-size:12px">',
'CA32' => '<font style="font-size:12px">',
'CA33' => '<font style="font-size:12px">',
'HI33' => '<font style="font-size:12px">',
'HI34' => '<font style="font-size:12px">',
'HI35' => '<font style="font-size:12px">',
'HI36' => '<font style="font-size:12px">',
'SA31' => '<font style="font-size:12px">',
'TS31' => '<font style="font-size:12px">',
'KC35' => '<font style="font-size:15px">',
'KC36' => '<font style="font-size:15px">',
'KC37' => '<font style="font-size:15px">',
'KC38' => '<font style="font-size:15px">',
);

our %SMALL_TAG_END = (
'D' => '</span>',
'A' => '</font>',
'V' => '</font>',
);

# $rhParams  : 通常パラメータ
# $rhParams2 : ループ内でも読めるパラメータ

sub insert {
	my ($name, $rhParams, $rhParams2) = @_;
	
	$rhParams  = {} unless ($rhParams);
	$rhParams2 = {} unless ($rhParams2);
	
	# 会員フラグ
	
	if ($_::U->{USER_ID}) {
		$rhParams2->{MEMBER} = 1;
		$rhParams2->{USER_ID}  = $_::U->{USER_ID};
		$rhParams2->{INFO_STR} = $_::U->makeInfoStr();
	} else {
		for my $key (qw(MEMBER USER_ID INFO_STR)) {
			delete($rhParams->{$key});
			delete($rhParams2->{$key});
		}
	}
	
	$rhParams2->{RAND} = rand();
	$rhParams2->{TIME} = time();
	$rhParams2->{TEST} = 1 if ($_::TEST_MODE);
	$rhParams2->{BasePath}    = Request::makeBasePath(
		{ host => $ENV{MB_HTTP_HOST} });
	$rhParams2->{SSLBasePath} = Request::makeSSLBasePath(
		{ host => $ENV{MB_HTTPS_HOST} });
	
	# 端末の文字サイズ設定が「標準」でも「小」でも同じサイズで
	# 表示できるようにするために使用
	
	if ($ENV{MB_CHARS_W} < 28) { # フォントサイズが標準以上の場合だけ
		$rhParams2->{SMALL_TAG} =
			$SMALL_TAG_M{$ENV{MB_MODEL_NAME}} ?
			$SMALL_TAG_M{$ENV{MB_MODEL_NAME}} :
			$SMALL_TAG_C{$ENV{MB_CARRIER_UA}};
		$rhParams2->{SMALL_TAG_END} = $SMALL_TAG_END{$ENV{MB_CARRIER_UA}};
	}
	
	# MobileEnv.pm で取得した内容
	
	$rhParams2->{CARRIER}     = $ENV{MB_CARRIER_UA};
	$rhParams2->{MODEL_TYPE}  = $ENV{MB_MODEL_TYPE};
	$rhParams2->{MODEL_NAME}  = $ENV{MB_MODEL_NAME};
	$rhParams2->{BROWSER_W}   = $ENV{MB_BROWSER_W};
	$rhParams2->{BROWSER_W2}  = $ENV{MB_BROWSER_W2};
	$rhParams2->{CHARS_W}     = $ENV{MB_CHARS_W};
	
	# テンプレート処理
	
	my $type = lc($ENV{MB_CARRIER_UA});
	my $html = MTemplate::insert(
		"$_::HTML_BIN_DIR/_system/$name.bin.$type",
			$rhParams, $rhParams2, $_::DEFAULT_CONFIG);
	
	return($html);
}

1;
