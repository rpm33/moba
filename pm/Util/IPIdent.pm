package Util::IPIdent;

=pod
----------------------------------------------------------------------
��³��IP���ɥ쥹Ƚ�̥⥸�塼��

������ˡ�ϡ�MobileEnv.pm �򻲹�
----------------------------------------------------------------------
=cut

use strict;
use FileHandle;

our @IPIDENT;
our @IP_MASK;

#--------------------------------------------------------
# ��³�� IP ���ɥ쥹Ƚ�̤ν����

sub init {
	my @files = @_;
	
	my $mask = 0;
	for my $i (0 .. 32) {
		if ($i != 0) {
			$mask |= (1 << (32 - $i));
		}
		$IP_MASK[$i] = $mask;
	}
	
	@IPIDENT = ();
	
	for my $file (@files) {
		my $fh = new FileHandle;
		open($fh, $file) || die;
		while (<$fh>) {
			chomp;
			add($_);
		}
		close($fh);
	}
}

#--------------------------------------------------------

sub add {
	my $config = shift;
	return unless ($config =~ m#^\s*(\d+)\s*\.\s*(\d+)\s*\.\s*(\d+)\s*\.\s*(\d+)\s*/\s*(\d+)\s+([A-Z])#x);
	my $mask = $IP_MASK[$5];
	my $net  = (($1 << 24) | ($2 << 16) | ($3 << 8) | $4) & $mask;
	push(@IPIDENT, [ $net, $mask, $6 ]);
}

#--------------------------------------------------------

sub get {
	my $addr = shift;
	return '' unless ($addr =~ /(\d+)\.(\d+)\.(\d+)\.(\d+)/);
	my $ip = ($1 << 24) | ($2 << 16) | ($3 << 8) | $4;
	for my $ref (@IPIDENT) {
		my ($net, $mask, $c) = @{$ref};
		if (($ip & $mask) == $net) {
			return $c;
		}
	}
	return '';
}

1;
