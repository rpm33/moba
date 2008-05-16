#!/usr/bin/perl

use strict;
use MobaConf;

createMap("$_::MCODE_DIR/H.dat", 'map/z2h.txt');
createMap("$_::MCODE_DIR/D.dat",                'map/a2d.txt', 'map/v2d.txt');
createMap("$_::MCODE_DIR/A.dat",                               'map/v2a.txt');
createMap("$_::MCODE_DIR/V.dat", 'map/d2v.txt', 'map/a2v.txt', 'map/v2v.txt');

#---------------------------------------

sub createMap {
	my ($out_file, @src_files) = @_;
	
	#---------------
	# READ
	
	my %text;
	my $text = chr(0);
	my @map;
	
	for my $src_file (@src_files) {
		print "$src_file ";
		my $line = 0;
		open(IN, $src_file) || die "Can't open file $src_file\n";
		while (<IN>) {
			$line++;
			s/\r?\n$//;
			
			next unless ($_ =~ /\t/);
			my ($from, $to) = ($`, $');
			
			$from = _toHexStr($from);
			if ($from !~ /^[\da-f]{4}$/i) {
				die "format error $src_file:$line\n";
			}
			$from = hex($from);
			
			$to = _toHexStr($to);
			if ($to !~ /^([\da-f][\da-f])*$/i) {
				die "format error $src_file:$line\n";
			}
			$to =~ s/[\da-f]{2}/chr(hex($&))/ieg;
			
			if ($to ne '' && !exists($text{$to})) {
				$text{$to} = length($text);
				$text .= ($to. chr(0));
			}
			$map[ $from ] = $text{$to};
		}
		close(IN);
	}
	
	#---------------
	# WRITE
	
	print "=> $out_file\n";
	open(OUT, ">$out_file");
	print OUT pack('L', 4 + 0x10000 * 2 + length($text));
	for my $i (0..0xffff) {
		print OUT pack('S', int($map[$i]));
	}
	print OUT $text;
	close(OUT);
}

#---------------------------------------

sub _toHexStr {
	my $text = shift;
	$text =~ s/''/'27'/g;
	$text =~ s('([^']*)') {
		my $in = $1;
		$in =~ s/./sprintf("%02X", ord($&))/eg;
		$in;
	}eg;
	$text =~ s/ +//g;
	return $text;
}

