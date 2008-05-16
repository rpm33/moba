package Kcode;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Kcode ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Kcode', $VERSION);

# Preloaded methods go here.

sub convert($$$) {
	my ($rData, $to, $from) = @_;
	if ($to eq 'sjis') {
		if ($from eq 'euc') {
			${$rData} = e2s(${$rData});
		}
		if ($from eq 'jis') {
			${$rData} = e2s(${$rData});
		}
	}
	elsif ($to eq 'euc') {
		if ($from eq 'sjis') {
			${$rData} = s2e(${$rData});
		}
		if ($from eq 'jis') {
			${$rData} = j2e(${$rData});
		}
	}
	elsif ($to eq 'jis') {
		if ($from eq 'euc') {
			${$rData} = e2j(${$rData});
		}
		if ($from eq 'sjis') {
			${$rData} = s2j(${$rData});
		}
	}
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Kcode - 高速な日本語文字コード変換

=head1 SYNOPSIS
  
  use Kcode;
  
  $str = Kcode::replaceS($str, %replace, [$striptags], [$maxlen]);
  $str = Kcode::replaceE($str, %replace, [$striptags], [$maxlen]);
  $sz  = Kcode::charsizeS($str);
  $sz  = Kcode::charsizeE($str);
  $str = Kcode::s2e($str);
  $str = Kcode::e2s($str);
  $str = Kcode::s2j($str);
  $str = Kcode::j2s($str);
  $str = Kcode::e2j($str);
  $str = Kcode::j2e($str);
  
=head1 DESCRIPTION
  
  $str = Kcode::replaceS($from_str, %replace, [$striptags], [$maxlen]);
  
  SJIS で %replace の key に該当する文字を value に置換した文字列を返す
  EUC の場合は replaceE を使う
  
  $sz = Kcode::charsizeS($str);
  
  $str を SJIS で解釈して先頭文字のバイト数を返す。
  EUC の場合は charsizeE を使う
  
  $str = Kcode::s2e($str);
  $str = Kcode::e2s($str);
  $str = Kcode::s2j($str);
  $str = Kcode::j2s($str);
  $str = Kcode::e2j($str);
  $str = Kcode::j2e($str);
  
  SJIS <=> EUC <=> JIS の相互変換を行う。
  
=cut
