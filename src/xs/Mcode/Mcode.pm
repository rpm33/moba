package Mcode;

use 5.008;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
);
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Mcode', $VERSION);

sub new {
	my ($pkg, $dir) = @_;
	my $self = {};
	die "dir not found '$dir'" if (!-d $dir);
	$self->{dir} = $dir;
	bless $self, $pkg;
}

sub DESTROY {
	my $self = shift;
	for my $map (values %{$self->{map}}) {
		Mcode::closeMap($map);
	}
}

sub u2any {
	my ($self, $str, $type, $maxlen) = @_;
	if (!$self->{map}{$type}) {
		die "bad type '$type'" if ($type =~ m#[/\.]#);
		my $map = Mcode::openMap("$self->{dir}/$type.dat");
		die "can't open map '$self->{dir}/$type.dat'" unless ($map);
		$self->{map}{$type} = $map;
	}
	return Mcode::_u2any($self->{map}{$type}, $str, $maxlen);
}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Mcode - ����������ʸ���Ѵ��⥸�塼��

=head1 SYNOPSIS

  use Mcode;
  
  $mcode = new Mcode('MCODE.DAT');
  
  $mcode->any2u($str        [, $maxlen]);
  $mcode->u2any($str, $type [, $maxlen]);
  $mcode->usub ($str, $maxlen);
  $mcode->checkEmoji($str);

=head1 DESCRIPTION

$conv = new Mcode($mcode_dir);

  ����ǥ��쥯�ȥ���Ѵ��ޥåץե����뤬�����ΤȤ��ơ�
  ʸ���Ѵ����֥������Ȥ��������롣

$conv->any2u($str);

  docomo/ezweb/vodafone ��ʸ��������������Ѵ�����

$conv->u2any($str, $type);

  ���������ʸ�������꥿���פ��Ѵ��ޥåפ���Ѥ����Ѵ����롣

$conv->usub($str, $length);

  ��������� $length ʸ��������ڤ�ͤ�롣��ʸ���б���

$conv->checkEmoji($str);

  �������ʸ����˳�ʸ�������äƤ����� 1 ���֤�������ʳ��� 0

=cut
