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

MTemplate - ��®�ʥƥ�ץ졼�ȥ饤�֥��

=head1 SYNOPSIS

use MTemplate;

$tpl = new MTemplate($compiled_template_file);

$tpl->insert($refParamHash);

=head1 ABSTRACT

��������ѥ��뤵�줿�ƥ�ץ졼�ȥХ��ʥ���Ѥ��ƹ�®�ʥƥ�ץ졼�Ƚ�����Ԥ��ޤ����롼�ס����ʬ�����ִ���URL ENCODE, HTMLSPECIALCHARS(+NL2BR) ����ǽ�ˤ��б����Ƥ��ꡢ����Ū��HTML�ƥ�ץ졼�Ȥν������б��Ǥ��ޤ���

=head1 DESCRIPTION

���줫���

=head1 SEE ALSO

MTemplate::Compiler

=cut
