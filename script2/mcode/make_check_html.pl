#!/usr/bin/perl

use strict;
use Mcode;

my $mcode = new Mcode('dat');

for my $from ('d', 'a', 'v') {
	for my $to ('d', 'a', 'v') {
		open(IN, "check/$from.html");
		my $html = join('', <IN>);
		close(IN);
		
		$html = $mcode->any2u($html);
		$html = $mcode->u2any($html, uc($to));
		
		open(OUT, ">check/$from". "2". "$to.html");
		print OUT qq|<html><head><title>$from to $to</title></head>|;
		print OUT qq|<body><pre>\n|;
		print OUT $html;
		print OUT qq|</pre></body></html>\n|;
		close(OUT);
	}
}
