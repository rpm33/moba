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

HTMLFast - HTML ���귿�������®�ˤ���

=head1 SYNOPSIS
  
  use HTMLFast;
  
  $str = HTMLFast::decode($str [,$metachar]);
  $str = HTMLFast::encode($str [,$metachar]);
  $str = HTMLFast::htmlspecialchars($str [,$nl2br]);
  
=head1 DESCRIPTION
  
  $str = HTMLFast::decode($str [,$metachar]);
  
  URL���󥳡��ɤ��줿ʸ�����ǥ����ɤ��롣
  $metachar �ϥǥե���Ȥ� "%" �����ꤵ��뤬��
  ���Х���ʸ���Ǥ����¾��ʸ���Ǥ�褤��
  
  $str = HTMLFast::encode($str [,$metachar]);
  
  ʸ�����URL���󥳡��ɤ��롣
  $metachar �ϥǥե���Ȥ� "%" �����ꤵ��뤬��
  ���Х���ʸ���Ǥ����¾��ʸ���Ǥ�褤��
  
  $str = HTMLFast::htmlspecialchars($str [,$nl2br]);
  
  ��<�ס�>�ס�"�ס�&�פ򡢤��줾�� &lt; &gt; &quot; &amp; ���Ѵ����롣
  $nl2br �� 0 �ʳ��ˤ���ȡ�LF => <br> ���Ѵ���Ʊ���˹Ԥ�

=cut
