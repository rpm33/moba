package Util::Die;

# use ����ȡ�die �����Ȥ��ˡ�@DIE_CALLER ��
# �ƤӽФ��ط������������褦�ˤʤ롣

use strict;

our @CALLER;

my $old_die_handler = $SIG{__DIE__};

$SIG{__DIE__} = sub {
	my $level = 0;
	my @caller;
	while (1) {
		my @data = caller($level);
		last unless (scalar(@data));
		push(@caller, \@data);
		$level++;
	}
	@CALLER = @caller;
	
	if ( $old_die_handler) {
		&$old_die_handler(@_);
	} else {
		die @_;
	}
};

1;
