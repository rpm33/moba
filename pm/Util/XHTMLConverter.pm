package Util::XHTMLConverter;

=pod
----------------------------------------------------------------------
CHTML => XHTML コンバーター

FOMA 向けに、CHTML のデータを XHTML に変換する。

※変換可能なタグ全てに対応しているわけではない。
※FOMA 以外につかった場合の表示は未検証。
----------------------------------------------------------------------
=cut

use strict;

my ($l_link, $l_alink, $l_vlink);

sub convert {
	my ($html, $is_sub) = @_;

	# テンプレタグの退避
	
	my @save;
	$html =~ s(\$[^\$]+\$) {
		push(@save, $&);
		'$';
	}egis;
	
	# 各タグの処理
	
	($l_link, $l_alink, $l_vlink) = ('', '', '');
	$html =~ s(<[^>]+>) {
		convert_tag($&);
	}egis;
	
	# ヘッダ挿入
	
	if (!$is_sub) {
		$html = <<'END' . $html;
<?xml version="1.0" encoding="Shift_JIS"?>
<!DOCTYPE html PUBLIC "-//i-mode group (ja)//DTD XHTML i-XHTML(Locale/Ver.=ja/1.1) 1.0//EN" "i-xhtml_4ja_10.dtd">
END
	}

	# CDATA 挿入
	
	if ($l_link ne '' || $l_alink ne '' || $l_vlink ne '') {
		my $ins = qq|<style type="text/css">\n<![CDATA[\n|;
		$ins .= "a:link{color:$l_link}\n"     if ($l_link ne '');
		$ins .= "a:focus{color:$l_alink}\n"   if ($l_alink ne '');
		$ins .= "a:visited{color:$l_vlink}\n" if ($l_vlink ne '');
		$ins .= "]]>\n</style>\n";
		$html =~ s#</head>#$ins\n</head>#;
	}
	
	# テンプレタグの戻し
	
	$html =~ s(\$) {
		shift(@save);
	}egis;
	
	return($html);
}

#-------------------------------------------------

sub convert_tag {
	my $all = shift;
	
	die "$all\n" unless ($all =~ m#^<([^\s]+)\s*(.*)/?>#is);
	
	my (@params, @styles, $single, $pre, $post);
	my ($tag, $params) = ($1, $2);
	
	while ($params =~ m#(\$)|([^\s="\$]+)(="([^"]+)")?#gis) {
		my $key = $1 eq '$' ? '$' : $2;
		my $val = $4;
		if ($key eq 'style') {
			for (split(/\s*;\s*/, $val)) {
				push(@styles, $_) if ($_ ne '');
			}
		} else {
			push(@params, [$key, $val]);
		}
	}
	
	#---------------
	# html
	
	if ($tag eq 'html') {
		return('<html xmlns="http://www.w3.org/1999/xhtml">');
	}
	
	#---------------
	# body
	
	elsif ($tag eq 'body') {
		for my $ref (@params) {
			if ($ref->[0] eq 'background') {
				$ref->[0] = '';
				push(@styles, "background-image:url($ref->[1])");
			}
			elsif ($ref->[0] eq 'bgcolor') {
				$ref->[0] = '';
				push(@styles, "background-color:$ref->[1]");
			}
			elsif ($ref->[0] eq 'text') {
				$ref->[0] = '';
				push(@styles, "color:$ref->[1]");
			}
			elsif ($ref->[0] eq 'link') {
				$ref->[0] = ''; $l_link = $ref->[1];
			}
			elsif ($ref->[0] eq 'alink') {
				$ref->[0] = ''; $l_alink = $ref->[1];
			}
			elsif ($ref->[0] eq 'vlink') {
				$ref->[0] = ''; $l_vlink = $ref->[1];
			}
		}
	}
	
	#---------------
	# div
	
	elsif ($tag eq 'div') {
		for my $ref (@params) {
			if ($ref->[0] eq 'align') {
				$ref->[0] = '';
				push(@styles, "text-align:$ref->[1]");
			}
			elsif ($ref->[0] eq 'bgcolor') {
				$ref->[0] = '';
				push(@styles, "background-color:$ref->[1]");
			}
		}
	}
	
	#---------------
	# span
	
	elsif ($tag eq 'span') {
		for my $ref (@params) {
			if ($ref->[0] eq 'bgcolor') {
				$ref->[0] = '';
				push(@styles, "background-color:$ref->[1]");
			}
		}
	}
	
	#---------------
	# center
	
	elsif ($tag eq 'center') {
		return('<div style="text-align:center">');
	}
	elsif ($tag eq '/center') {
		return('</div>');
	}
	
	#---------------
	# br
	
	elsif ($tag eq 'br') {
		$single = 1;
		for my $ref (@params) {
			if ($ref->[0] eq 'clear') {
				$ref->[0] = '';
				if      ($ref->[1] eq 'all') {
					return('<div style="clear:both"></div>');
				} elsif ($ref->[1] =~ /^left|right$/) {
					return(qq|<div style="clear:$ref->[1]"/>|);
				}
			}
		}
	}
	
	#---------------
	# a
	
	elsif ($tag eq 'a') {
		for my $ref (@params) {
			if ($ref->[0] eq 'name') {
				$ref->[0] =  'id';
			}
			elsif ($ref->[0] eq 'utn') {
				$ref->[1] =  'utn';
			}
		}
	}
	
	#---------------
	# img
	
	elsif ($tag eq 'img') {
		$single = 1;
		for my $ref (@params) {
			if ($ref->[0] eq 'align') {
				$ref->[0] = '';
				if ($ref->[1] =~ /^top|middle|bottom$/) {
					push(@styles, "vertical-align:$ref->[1]");
				}
				if ($ref->[1] =~ /^left|right$/) {
					push(@styles, "float:$ref->[1]");
				}
			}
			elsif ($ref->[0] =~ /^hspace$/) {
				$ref->[0] = '';
				push(@styles, "margin-left:$ref->[1]");
				push(@styles, "margin-right:$ref->[1]");
			}
			elsif ($ref->[0] =~ /^vspace$/) {
				$ref->[0] = '';
				push(@styles, "margin-top:$ref->[1]");
				push(@styles, "margin-bottom:$ref->[1]");
			}
		}
	}
	
	#---------------
	# font
	
	elsif ($tag eq 'font') {
		$tag = 'span';
		for my $ref (@params) {
			if ($ref->[0] =~ /^color$/) {
				$ref->[0] = '';
				push(@styles, "color:$ref->[1]");
			}
			if ($ref->[0] =~ /^size$/) {
				$ref->[0] = '';
				if      ($ref->[1] eq '+1') {
					push(@styles, "font-size:larger");
				} elsif ($ref->[1] eq '-1') {
					push(@styles, "font-size:smaller");
				} elsif ($ref->[1] eq '1') {
					push(@styles, "font-size:x-small");
				} elsif ($ref->[1] eq '2') {
					push(@styles, "font-size:small");
				} elsif ($ref->[1] eq '3') {
					push(@styles, "font-size:medium");
				} elsif ($ref->[1] eq '4') {
					push(@styles, "font-size:large");
				} elsif ($ref->[1] eq '5') {
					push(@styles, "font-size:x-large");
				} elsif ($ref->[1] eq '6') {
					push(@styles, "font-size:xx-large");
				} elsif ($ref->[1] eq '7') {
					push(@styles, "font-size:xx-large");
				}
			}
		}
	}
	elsif ($tag eq '/font') {
		return('</span>');
	}
	
	#---------------
	# blink
	
	elsif ($tag eq 'blink') {
		return('<span style="text-decoration:blink">');
	}
	elsif ($tag eq '/blink') {
		return('</span>');
	}
	
	#---------------
	# marquee
	
	elsif ($tag eq 'marquee') {
		$tag = 'div';
		push(@styles, "display:-wap-marquee");
		my $bgcolor;
		for my $ref (@params) {
			if ($ref->[0] eq 'behavior') {
				$ref->[0] = '';
				push(@styles, "-wap-marquee-style:$ref->[1]");
			}
			elsif ($ref->[0] eq 'direction') {
				$ref->[0] = '';
				my $dir = ($ref->[1] eq 'right') ? 'ltr' : 'rtl';
				push(@styles, "-wap-marquee-dir:$dir");
			}
			elsif ($ref->[0] eq 'loop') {
				$ref->[0] = '';
				push(@styles, "-wap-marquee-loop:$ref->[1]");
			}
			elsif ($ref->[0] eq 'bgcolor') {
				$ref->[0] = '';
				$bgcolor = $ref->[1]
			}
		}
		if ($bgcolor) {
			$pre .= qq|<div style="background-color:$bgcolor">|;
		} else {
			$pre .= '<div>';
		}
	}
	elsif ($tag eq '/marquee') {
		return('</div></div>');
	}
	
	#---------------
	# hr
	
	elsif ($tag eq 'hr') {
		$single = 1;
		my $noshade = 0;
		for my $ref (@params) {
			if ($ref->[0] eq 'align') {
				$ref->[0] = '';
				if ($ref->[1] eq /^left|right$/) {
					push(@styles, "float:$ref->[1]");
				}
				elsif ($ref->[1] eq /^center$/) {
					push(@styles, "float:none");
				}
			}
			elsif ($ref->[0] eq 'size') {
				$ref->[0] = '';
				push(@styles, "height:$ref->[1]");
			}
			elsif ($ref->[0] eq 'width') {
				$ref->[0] = '';
				push(@styles, "width:$ref->[1]");
			}
			elsif ($ref->[0] eq 'noshade') {
				$ref->[0] = '';
				$noshade = 1;
			}
			elsif ($ref->[0] eq 'color') {
				$ref->[0] = '';
				$noshade = 1;
				push(@styles, "border-color:$ref->[1]");
				push(@styles, "background-color:$ref->[1]");
			}
		}
		if ($noshade) {
			push(@styles, "border-style:solid");
		}
	}
	
	#---------------
	# form
	
	elsif ($tag eq 'form') {
		for my $ref (@params) {
			if ($ref->[0] eq 'utn') {
				$ref->[1] =  'utn';
			}
		}
	}
	
	#---------------
	# select
	
	elsif ($tag eq 'select') {
		for my $ref (@params) {
			if ($ref->[0] eq 'multiple') {
				$ref->[1] =  'multiple';
			}
		}
	}
	
	#---------------
	# option
	
	elsif ($tag eq 'option') {
		$single = 1;
		for my $ref (@params) {
			if ($ref->[0] eq 'selected') {
				$ref->[1] =  'selected';
			}
		}
	}
	
	#---------------
	# input
	
	elsif ($tag eq 'input') {
		$single = 1;
		for my $ref (@params) {
			if ($ref->[0] eq 'checked') {
				$ref->[1] =  'checked';
			}
			elsif ($ref->[0] eq 'istyle') {
				$ref->[0] = '';
				my $type =
					($ref->[1] eq '1') ? 'h'  :
					($ref->[1] eq '2') ? 'hk' :
					($ref->[1] eq '3') ? 'en' :
					($ref->[1] eq '4') ? 'n'  : 'n';
				push(@styles,
					"-wap-input-format:&quot;*&lt;ja:$type&gt;&quot;");
			}
		}
	}
	
	else {
		return($all);
	}
	
	if (scalar(@styles)) {
		push(@params, [ 'style', join(';', @styles) ]);
	}
	
	return
		$pre. "<$tag". join('',
			map {
				if ($_->[0] eq '$') {
					'$';
				} else {
					qq| $_->[0]="$_->[1]"|;
				}
			}
			grep { $_->[0] ne '' } @params).
		($single ? "/>" : '>'). $post;
}

1;
