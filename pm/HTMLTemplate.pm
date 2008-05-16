package HTMLTemplate;

=pod
----------------------------------------------------------------------
��Х�����HTML�ƥ�ץ졼�Ƚ�����MTemplate �ؤ� wrapper��

MTemplate.pm ���Ϥ����̥ѥ�᡼�������ꤹ�롣
ɬ�פ˱����ƥѥ�᡼�����ɲä��Ƥ������ȡ�
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;
use MTemplate;

# small �����ʥ���ꥢ�ǥե���ȡ�

our %SMALL_TAG_C = (
'D' => '<span style="font-size:smaller">',
'A' => '<font size="1">',
'V' => '<font style="font-size:15px">',
);

# small �����ʸ��̵����

# ��au �� 12 px �ե���Ȥ�ɽ�����������Ȥ��λ�����ˡ��
#   ����ˤ�äƤޤ��ޤ��ʤ������������б����ʲ��Ϥ��ΰ��㡣

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

# $rhParams  : �̾�ѥ�᡼��
# $rhParams2 : �롼����Ǥ��ɤ��ѥ�᡼��

sub insert {
	my ($name, $rhParams, $rhParams2) = @_;
	
	$rhParams  = {} unless ($rhParams);
	$rhParams2 = {} unless ($rhParams2);
	
	# ����ե饰
	
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
	
	# ü����ʸ�����������꤬��ɸ��פǤ�־��פǤ�Ʊ����������
	# ɽ���Ǥ���褦�ˤ��뤿��˻���
	
	if ($ENV{MB_CHARS_W} < 28) { # �ե���ȥ�������ɸ��ʾ�ξ�����
		$rhParams2->{SMALL_TAG} =
			$SMALL_TAG_M{$ENV{MB_MODEL_NAME}} ?
			$SMALL_TAG_M{$ENV{MB_MODEL_NAME}} :
			$SMALL_TAG_C{$ENV{MB_CARRIER_UA}};
		$rhParams2->{SMALL_TAG_END} = $SMALL_TAG_END{$ENV{MB_CARRIER_UA}};
	}
	
	# MobileEnv.pm �Ǽ�����������
	
	$rhParams2->{CARRIER}     = $ENV{MB_CARRIER_UA};
	$rhParams2->{MODEL_TYPE}  = $ENV{MB_MODEL_TYPE};
	$rhParams2->{MODEL_NAME}  = $ENV{MB_MODEL_NAME};
	$rhParams2->{BROWSER_W}   = $ENV{MB_BROWSER_W};
	$rhParams2->{BROWSER_W2}  = $ENV{MB_BROWSER_W2};
	$rhParams2->{CHARS_W}     = $ENV{MB_CHARS_W};
	
	# �ƥ�ץ졼�Ƚ���
	
	my $type = lc($ENV{MB_CARRIER_UA});
	my $html = MTemplate::insert(
		"$_::HTML_BIN_DIR/_system/$name.bin.$type",
			$rhParams, $rhParams2, $_::DEFAULT_CONFIG);
	
	return($html);
}

1;
