package HTMLFast;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use HTMLFast ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('HTMLFast', $VERSION);

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

HTMLFast - HTML の定型処理を高速にする

=head1 SYNOPSIS
  
  use HTMLFast;
  
  $str = HTMLFast::decode($str [,$metachar]);
  $str = HTMLFast::encode($str [,$metachar]);
  $str = HTMLFast::htmlspecialchars($str [,$nl2br]);
  
=head1 DESCRIPTION
  
  $str = HTMLFast::decode($str [,$metachar]);
  
  URLエンコードされた文字列をデコードする。
  $metachar はデフォルトで "%" が指定されるが、
  １バイト文字であれば他の文字でもよい。
  
  $str = HTMLFast::encode($str [,$metachar]);
  
  文字列をURLエンコードする。
  $metachar はデフォルトで "%" が指定されるが、
  １バイト文字であれば他の文字でもよい。
  
  $str = HTMLFast::htmlspecialchars($str [,$nl2br]);
  
  「<」「>」「"」「&」を、それぞれ &lt; &gt; &quot; &amp; に変換する。
  $nl2br を 0 以外にすると、LF => <br> の変換も同時に行う

=cut
