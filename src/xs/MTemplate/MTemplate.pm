package MTemplate;

use 5.008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('MTemplate', $VERSION);

1;

__END__

=head1 NAME

MTemplate - 高速なテンプレートライブラリ

=head1 SYNOPSIS

use MTemplate;

$tpl = new MTemplate($compiled_template_file);

$tpl->insert($refParamHash);

=head1 ABSTRACT

事前コンパイルされたテンプレートバイナリを用いて高速なテンプレート処理を行います。ループ・条件分岐・置換（URL ENCODE, HTMLSPECIALCHARS(+NL2BR) が可能）に対応しており、基本的なHTMLテンプレートの処理に対応できます。

=head1 DESCRIPTION

これから書く

=head1 SEE ALSO

MTemplate::Compiler

=cut
