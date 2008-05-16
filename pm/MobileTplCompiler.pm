package MobileTplCompiler;

=pod
----------------------------------------------------------------------
HTML�ƥ�ץ졼�Ȥ򥳥�ѥ��뤷�ƥХ��ʥ�����Υƥ�ץ졼�Ȥ���������
�ʢ�script/tool/compile_template �ν������Ρ�

MTemplate::Compiler.pm �ˤϥ�Х����ͭ�ν����Ϥ��ޤ����äƤ��餺��
���Υ⥸�塼��ǥץꥳ��ѥ���Ȥ��Ƥν�����Ԥ���
----------------------------------------------------------------------
=cut

use Time::Local;
use FileHandle;
use File::Path;

use strict;
use MobaConf;
use HTMLFast;
use Mcode;
use MTemplate::Compiler;
use Util::XHTMLConverter;

$_::MCODE = new Mcode($_::MCODE_DIR) if (!$_::MCODE);

#---------------------------------------------------------------------
# ���ƥ�ץ졼�Ȥ򥳥�ѥ���

sub compile_all {
	my ($path, $refresh) = @_;
	
	my @types = ('d', 'a', 'v');
	
	my $last_time  = 0;
	my $rhConst    = {};
	my $rhStyle    = {};
	my $rhIncHtml  = parseInc("$_::TEMPLATE_DIR/_inc_html.txt");
	
	for my $type (@types) {
		$rhConst->{$type} = parseConst("$_::TEMPLATE_DIR/_const.txt");
		$rhStyle->{$type} = parseStyle("$_::TEMPLATE_DIR/_style.txt");
	}
	
	{
		my $t1 = get_mtime("$_::TEMPLATE_DIR/_inc_html.txt");
		my $t2 = get_mtime("$_::TEMPLATE_DIR/_const.txt");
		my $t3 = get_mtime("$_::TEMPLATE_DIR/_style.txt");
		
		$last_time = $t1 if ($last_time < $t1);
		$last_time = $t2 if ($last_time < $t2);
		$last_time = $t3 if ($last_time < $t3);
	}
	$last_time = time() if ($refresh);
	
	if (!-d "$_::TEMPLATE_DIR/$path") {
		die "$_::TEMPLATE_DIR/$path is not dir\n";
	}
	my $rhPaths = {};
	getFilePaths($rhPaths, $path);
	
	for my $name (sort keys(%{$rhPaths})) {
		my $mtime =
			$rhPaths->{$name} > $last_time ?
			$rhPaths->{$name} : $last_time;
		for my $type (@types) {
			compile_one(
				$name, $type, $mtime, $rhIncHtml, $rhConst, $rhStyle);
		}
	}
}

# �ƥ�ץ졼�ȤΥꥹ�Ȥ����
# ��Ʊ������ǰ��ֿ������ե�����Υ����ॹ����פ������

sub getFilePaths {
	my ($rhPaths, $path) = @_;
	
	my $dh = new FileHandle;
	opendir($dh, "$_::TEMPLATE_DIR/$path");
	while (my $file = readdir($dh)) {
		chomp($file);
		next if ($file =~ /^\./);
		
		my $file2 = "$_::TEMPLATE_DIR/$path/$file";
		if (-d $file2) {
			getFilePaths($rhPaths, "$path/$file");
			
		} elsif ($file =~ /(?:\.[dav])?\.html/) {
			my $mtime = get_mtime($file2);
			my $name  = "$path/$`";
			if ($rhPaths->{$name} < $mtime || !$rhPaths->{$name}) {
				$rhPaths->{$name} = $mtime;
			}
		}
	}
	closedir($dh);
}

#---------------------------------------
# ���󥯥롼�ɥե�������ɤ߹���

sub parseInc {
	my ($filename) = @_;
	my $fh = new FileHandle;
	open($fh, $filename) || return({});
	my $text = join('', <$fh>);
	close($fh);
	
	my $rHash = {};
	while ($text =~ m#\$INCDEF:([^\$]+)\$(.*?)\$/INCDEF\$#gis) {
		my ($name, $content) = ($1, $2);
		$content =~ s/^\r?\n//;
		$content =~ s/^\r?\n$//;
		$rHash->{$name} = $content;
	}
	return($rHash);
}

#---------------------------------------
# ����ե�������ɤ߹���

sub parseConst {
	my ($filename) = @_;
	my $rHash = {};
	my $fh = new FileHandle;
	open($fh, $filename) || return({});
	while (<$fh>) {
		my $line = $_;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/^#.*//;
		if ($line =~ /^([^:\s]+)\s*:\s*/) {
			$rHash->{$1} = $';
		}
	}
	close($fh);
	return($rHash);
}

#---------------------------------------
# ��������ե�������ɤ߹���

sub parseStyle {
	my ($filename) = @_;
	my $rHash = {};
	my $fh = new FileHandle;
	open($fh, $filename) || return({});
	my $style;
	while (<$fh>) {
		my $line = $_;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/^#.*//;
		if ($line =~ /^([^\s]+)\s*\{$/) {
			$style = $1;
			$rHash->{$style} = {} unless (defined($rHash->{$style}));
		} elsif ($line =~ /^\}$/) {
			$style = '';
		} elsif ($line =~ /^([^:\s]+)\s*:\s*/) {
			my ($key, $val) = ($1, $');
			if ($style) {
				$rHash->{$style}->{$key} = $val;
			}
		}
	}
	close($fh);
	return($rHash);
}

#---------------------------------------------------------------------
# ñ�쥿���פΥƥ�ץ졼������

sub compile_one {
	my ($srcName, $type, $mtime,
	    $rhIncHtml, $rhConst, $rhStyle) = @_;
	
	return unless ($srcName =~ m#^/(.*)/([^/]+)$#);
	my ($path, $name) = ($1, $2);
	my $saveDir  = "$_::HTML_BIN_DIR/$path";
	my $saveFile = "$saveDir/$name.bin.$type";
	my $text     =  readFile($srcName, $type);
	
	my $mtime2 = get_mtime($saveFile);
	return if ($mtime < $mtime2);
	
	print "$srcName($type)\n";
	
	processPreINC (\$text, $type, $rhIncHtml);
	processPreDOM (\$text, $type);
	processPreSTY (\$text, $type, $rhStyle);
	processPreCON (\$text, $type, $rhConst);
	processPreENC (\$text, $type);
	processPrePath(\$text, $srcName);
	processPreTags(\$text, $type);
	processPreMoji(\$text, $type);
	processPreDate(\$text, $type);
	processPreCmt (\$text, $type);
	
	$text = $_::MCODE->any2u($text);
	
	if ($type eq 'd') {
		$text = Util::XHTMLConverter::convert($text, $srcName =~ /\.sub$/);
	}
	mkpath($saveDir, 0, 0755) if (!-e $saveDir);
	MTemplate::Compiler::compile(\$text, $saveFile);
}

#---------------------------------------------------------------------
# �ƥ�ץ졼�ȥե�������ɤ߹���

sub readFile {
	my ($src_name, $type, $ext) = @_;
	
	$src_name =~ s#^/##;
	
	my $file = '';
	for my $type (".$type", "") {
		for my $ext ("html", "xhtml") {
			if (-e "$_::TEMPLATE_DIR/$src_name$type.$ext") {
				$file = "$_::TEMPLATE_DIR/$src_name$type.$ext";
				last;
			}
		}
		last if ($file);
	}
	my $fh = new FileHandle;
	open($fh, $file) || return('');
	my $html = join('', <$fh>);
	close($fh);
	
	return($html);
}

#---------------------------------------------------------------------
# ���󥯥롼�ɽ���

sub processPreINC {
	my ($rHtml, $type, $rhInc, $name, %included) = @_;
	
	if ($name) {
		if ($included{$name}) {
			my $names = join(',', sort keys %included);
			die "INC:$names recursively defined (type:$type)";
		}
		$included{$name} = 1;
	}
	
	${$rHtml} =~ s/\$\{INC:(.*?)\}\$/\:{INC:$1\}:/gis;
	${$rHtml} =~ s/\$INC:(.*?)\$/\:{INC:$1\}:/gis;
	
	${$rHtml} =~ s(:\{INC:(.*?)(:(.*?))?\}:) {
		my ($name, $params) = ($1, $3);
		my %params;
		if ($params) {
			for my $set (split(/, */, $params)) {
				my ($key, $val);
				if ($set =~ /=/) {
					($key, $val) = ($`, $');
				} else {
					($key, $val) = ($set, '');
				}
				$val =~ s/\%/\$/g;
				$params{$key} = $val;
			}
		}
		my $sub = $rhInc->{$name};
		if (!defined($sub)) {
			die "INC:$name not defined (type:$type)\n";
		}
		$sub =~ s/\$=T:([^\$]+)\$/$params{$1}/gis;
		processPreINC(\$sub, $type, $rhInc, $name, %included);
		($sub);
	}egis;
}

#---------------------------------------------------------------------
# ����ꥢ�������̤���ʬ�����

# $DOM:d,a,v$ �� $/DOM$

sub processPreDOM {
	my ($rText, $type) = @_;
	my $newText;
	my @part = split(/(\$\/?DOM(?::[dav,]+)?\$)/, ${$rText});
	my $num = scalar(@part);
	
	return if ($num == 0);
	
	my $type2 = substr($type, 0, 1);
	for (my $i = 0; $i < $num; $i++) {
		my $part = $part[$i];
		if ($part =~ /^\$(\/)?DOM(:([dav,]+))?\$/) {
			my ($mode, $types) = ($1, ",$3,");
			if ($mode ne '/' && $types !~ /,($type|$type2),/) {
				my $depth = 1;
				while ($depth > 0) {
					$i++;
					die if ($i == $num);
					my $tmp = $part[$i];
					if ($tmp =~ /^\$(\/)?DOM(:[dav,]+)?\$/) {
						if ($1 eq '/') {
							$depth--;
						} else {
							$depth++;
						}
					}
				}
			}
		} else {
			$newText .= $part;
		}
	}
	${$rText} = $newText;
}

#---------------------------------------------------------------------
# ���������������

# $STY:���������ѿ�̾$
# $STY_USE:������������̾$

sub processPreSTY {
	my ($rText, $type, $rhStyle) = @_;
	
	my @styles = ('default');
	${$rText} =~ s(\$STY_USE:([^\$]+)\$) {
		push(@styles, $1); '';
	}egis;
	
	my %style;
	for my $style (@styles) {
		my $rhSrcStyle = $rhStyle->{$type}->{$style};
		if (!defined($rhSrcStyle)) {
			die "STY_USE:$style not defined (type:$type)\n";
		}
		for my $key (keys %{$rhSrcStyle}) {
			$style{$key} = $rhSrcStyle->{$key};
		}
	}
	
	${$rText} =~ s(\$STY:([^:\$]*)\$) {
		my $key = $1;
		if (!defined($style{$key})) {
			die "STY:$key not defined (type:$type)\n";
		}
		$style{$key};
	}egis;
}

#---------------------------------------------------------------------
# �����������

# $CON:���̾$

sub processPreCON {
	my ($rText, $type, $rhConst) = @_;
	${$rText} =~ s(\$CON:([^\$]*)\$) {
		my $key = $1;
		my $val = $rhConst->{$type}->{$key};
		if (!defined($val)) {
			die "CON:$key not defined (type:$type)\n";
		}
		$val;
	}egis;
}

#---------------------------------------------------------------------
# URL���󥳡��ɤν���

# $ENC:ʸ����$

sub processPreENC {
	my ($rText, $type) = @_;
	${$rText} =~ s(\$ENC:([^\$]*)\$) {
		my $text = $1;
		$text = HTMLFast::encode($text);
		($text);
	}egis;
}

#---------------------------------------------------------------------
# ����ꥢ��ͭ�������Ѵ�

sub processPreTags {
	my ($rHtml, $type) = @_;
	
	# istyle
	
	if ($type =~ /^v/) {
		${$rHtml} =~ s(istyle="([1-4])") {
			my $mode = '';
			if    ($1 eq '1') { $mode = 'hiragana'; }
			elsif ($1 eq '2') { $mode = 'katakana'; }
			elsif ($1 eq '3') { $mode = 'alphabet'; }
			elsif ($1 eq '4') { $mode = 'numeric';  }
			qq|mode="$mode"|;
		}egis;
	}
}

#---------------------------------------------------------------------
# �����ɻ���ʸ���Ѵ�

sub processPreMoji {
	my ($rHtml) = @_;
	
	${$rHtml} =~ s(&#(\d{1,5});) {
		my $chr = int($1);
		$chr < 0x100 ?
			pack('C', $chr) : pack('CC', $chr >> 8, $chr & 0xFF);
	}egis;
	
	${$rHtml} =~ s(&#x([0-9a-f]{1,4});) {
		my $chr = hex($1);
		$chr < 0x100 ?
			pack('C', $chr) : pack('CC', $chr >> 8, $chr & 0xFF);
	}egis;
}

#---------------------------------------------------------------------
# ���վ�������Ѵ�

# ::TIME(YYYY/[M]M/[D]D [H]H:II)

sub processPreDate {
	my ($rHtml, $type) = @_;
	
	${$rHtml} =~ s{::TIME\(\s*(\d{4})/(\d\d?)/(\d\d?)\s+(\d\d?):(\d\d?)\s*\)} {
		int(timelocal(0,$5,$4,$3,$2-1,$1));
	}egs;
}

#---------------------------------------------------------------------
# �����ȡ�̵�̥��ڡ�������

sub processPreCmt {
	my ($rHtml, $type, $isMail) = @_;
	
	${$rHtml} =~ s/<!--.*?-->//gis;
	${$rHtml} =~ s/\r?\n/\n/gi;
	${$rHtml} =~ s/\r/\n/gi;
	
	if ($isMail) {
		${$rHtml} =~ s/\n\n\n+/\n\n/g; # ���İʾ�ζ��Ԥϵͤ��
		${$rHtml} =~ s/\t +/ /g;
	} else {
		${$rHtml} =~ s(( +)[\r\n\t ]+) {
			my ($spc_p, $spc) = ($1, $&);
			if ($spc =~ /\n/) {
				if ($spc_p) {
					$spc = " \n";
				} else {
					$spc = "\n";
				}
			} else {
				$spc = " ";
			}
			$spc;
		}egis;
	}
	${$rHtml} =~ s/<!!--/<!--/gis;
}

#---------------------------------------------------------------------
# ���������󥯤����Хѥ���

sub processPrePath {
	my ($rHtml, $srcName) = @_;
	if ($srcName =~ m#^/_system/# && $srcName =~ m#[^/]+$#) {
		$srcName = "/$&";
	} elsif ($srcName =~ m#^/_html/#) {
		$srcName = "/$'";
	}
	
	${$rHtml} =~ s(<(a|form) ([^<>]*)(href|action)="([^"]+)"([^<>]*)>) {
		my ($tag, $pre, $param, $value, $post) = ($1, $2, $3, $4, $5);
		
		if ($value =~ m#^//#) {
			$value = "/$'";
		} elsif ($value =~ /^#/) {
		} elsif ($value !~ /^[^:\/]+:/ && $value !~ /^\$/) {
			$value = relPath($srcName, absPath($srcName, $value));
		}
		
		qq|<$tag $pre$param="$value"$post>|;
	}egis;
}

# ���Хѥ�����

sub relPath {
	my ($srcName, $tgtName) = @_;
	$srcName = " $srcName ";
	$tgtName = " $tgtName ";
	my (@srcPath) = split('/', $srcName);
	my (@tgtPath) = split('/', $tgtName);
	push(@srcPath, '') if ($srcName =~ m#/$#);
	push(@tgtPath, '') if ($tgtName =~ m#/$#);
	pop(@srcPath);
	
	for (my $i = 0;
		$srcPath[0] eq $tgtPath[0] &&
		$i < scalar(@srcPath) && $i < scalar(@tgtPath); $i++) {
		shift(@srcPath);
		shift(@tgtPath);
	}
	
	my @path;
	while (scalar(@srcPath)) {
		pop(@srcPath);
		push(@path, '..');
	}
	for (@tgtPath) {
		push(@path, $_);
	}
	my $ret = join('/', @path);
	$ret =~ s/^ //;
	$ret =~ s/ $//;
	$ret .= '/' if ($ret =~ /\.\.$/);
	$ret = "./"     if ($ret eq '');
	$ret = "./$ret" if ($ret =~ /^\?/);
	return($ret);
}

# ���Хѥ��Ѵ�

sub absPath {
	my ($baseHref, $path) = @_;
	
	$baseHref =~ s#[^/]+$##;
	if ($path !~ m#^[^:\/]+:# && $path !~ m#^/#) {
		$path = $baseHref. $path;
	}
	$path =~ s#(?=/)\./##g;
	while ($path =~ m#[^/]+/\.\./#) {
		$path = "$`/$'";
	}
	return($path);
}

# �ե����뽤����������

sub get_mtime {
	my $filename = shift;
	(stat($filename))[9];
}

1;
