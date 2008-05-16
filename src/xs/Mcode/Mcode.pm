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

Mcode - ケータイ用文字変換モジュール

=head1 SYNOPSIS

  use Mcode;
  
  $mcode = new Mcode('MCODE.DAT');
  
  $mcode->any2u($str        [, $maxlen]);
  $mcode->u2any($str, $type [, $maxlen]);
  $mcode->usub ($str, $maxlen);
  $mcode->checkEmoji($str);

=head1 DESCRIPTION

$conv = new Mcode($mcode_dir);

  指定ディレクトリに変換マップファイルがあるものとして、
  文字変換オブジェクトを生成する。

$conv->any2u($str);

  docomo/ezweb/vodafone 絵文字を統合形式に変換する

$conv->u2any($str, $type);

  統合形式の文字列を指定タイプの変換マップを使用して変換する。

$conv->usub($str, $length);

  統合形式を $length 文字以内に切り詰める。絵文字対応。

$conv->checkEmoji($str);

  統合形式文字列に絵文字が入っていたら 1 を返す。それ以外は 0

=cut
