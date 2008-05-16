package MobaConf;

use 5.008;
use strict;
use warnings;

if (!$ENV{MOBA_DIR}) {
	die "\$ENV{MOBA_DIR} is not set";
}
my $config_file = "$ENV{MOBA_DIR}/conf/main.conf";

eval {
	require $config_file;
};
if ($@) {
	die "can't open $config_file";
}

1;

__END__

=head1 NAME

MobaConf - ����������ɥ⥸�塼��

=head1 SYNOPSIS

  use MobaConf;

=head1 DESCRIPTION

  use MobaConf;
  
  ��¹Ԥ���ȡ�$ENV{MOBA_CONFIG_FILE} �� require ����롣
  ������������Ǥ���
  
=cut
