package Util::Die;

# use すると、die したときに、@DIE_CALLER に
# 呼び出し関係を全部いれるようになる。

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
