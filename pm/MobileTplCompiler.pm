package MobileTplCompiler;

=pod
----------------------------------------------------------------------
HTMLテンプレートをコンパイルしてバイナリ形式のテンプレートを生成する
（※script/tool/compile_template の処理本体）

MTemplate::Compiler.pm にはモバイル固有の処理はあまり入っておらず、
このモジュールでプリコンパイラとしての処理を行う。
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
# 全テンプレートをコンパイル

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

# テンプレートのリストを取得
# （同一系統で一番新しいファイルのタイムスタンプを取得）

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
# インクルードファイルの読み込み

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
# 定数ファイルの読み込み

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
# スタイルファイルの読み込み

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
# 単一タイプのテンプレート生成

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
# テンプレートファイルを読み込む

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
# インクルード処理

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
# キャリアタイプ別の部分を処理

# $DOM:d,a,v$ 〜 $/DOM$

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
# スタイルの埋め込み

# $STY:スタイル変数名$
# $STY_USE:スタイル設定名$

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
# 定数の埋め込み

# $CON:定数名$

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
# URLエンコードの処理

# $ENC:文字列$

sub processPreENC {
	my ($rText, $type) = @_;
	${$rText} =~ s(\$ENC:([^\$]*)\$) {
		my $text = $1;
		$text = HTMLFast::encode($text);
		($text);
	}egis;
}

#---------------------------------------------------------------------
# キャリア固有タグの変換

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
# コード指定文字変換

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
# 日付条件指定の変換

# ::TIME(YYYY/[M]M/[D]D [H]H:II)

sub processPreDate {
	my ($rHtml, $type) = @_;
	
	${$rHtml} =~ s{::TIME\(\s*(\d{4})/(\d\d?)/(\d\d?)\s+(\d\d?):(\d\d?)\s*\)} {
		int(timelocal(0,$5,$4,$3,$2-1,$1));
	}egs;
}

#---------------------------------------------------------------------
# コメント、無駄スペース除去

sub processPreCmt {
	my ($rHtml, $type, $isMail) = @_;
	
	${$rHtml} =~ s/<!--.*?-->//gis;
	${$rHtml} =~ s/\r?\n/\n/gi;
	${$rHtml} =~ s/\r/\n/gi;
	
	if ($isMail) {
		${$rHtml} =~ s/\n\n\n+/\n\n/g; # ２つ以上の空行は詰める
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
# サイト内リンクを相対パスに

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

# 相対パス生成

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

# 絶対パス変換

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

# ファイル修正日時取得

sub get_mtime {
	my $filename = shift;
	(stat($filename))[9];
}

1;
