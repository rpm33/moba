#!/usr/bin/perl

BEGIN { $ENV{MOBA_DIR} = '..'; }

use FCGI;
use Time::HiRes;

use strict;
use MobaConf;
use MLog;
use DA;
use Page::Main;
use Util::Die;

srand($$);

our $RESTART_TIME = time() + 300 + rand(120); # 再起動時刻(5〜7分)
our $FCGI_REQ     = undef;

our $TERM = 0;

eval {
	require "$_::CONF_DIR/pages.conf";
	
	DA::release();
	
	$FCGI_REQ = FCGI::Request();
	while ($FCGI_REQ->Accept() >= 0) {
		local $SIG{'HUP'}  =
		local $SIG{'USR1'} =
		local $SIG{'TERM'} =
		local $SIG{'PIPE'} =
			sub { $TERM = 1; };
		
		Page::Main::main();
		
		DA::release();
		
		$FCGI_REQ->Finish();
		
		$TERM = 1 if (time() > $RESTART_TIME);
		last if ($TERM);
	}
};

if ($@) {
	my $e   = MException::getInfo($@);
	my $msg = MException::makeMsg($e);
	
	my @caller;
	for my $ref (@Util::Die::CALLER) {
		my ($file, $line) = @{$ref}[1,2];
		my $home_expr = quotemeta($_::HOME_DIR). "/?";
		$file =~ s/^$home_expr//;
		push(@caller, "$file:$line");
	}
	my $caller = join(" > ", @caller);
	
	MLog::write("$_::LOG_DIR/fcgi.die",
		"index.fcgi\t".
		"UA:  $ENV{HTTP_USER_AGENT}\t".
		"REQ: $ENV{REQUEST_METHOD} $ENV{REQUEST_URI}\t".
		"REF: $ENV{HTTP_REFERER}\t".
		"$msg\t$caller");
	
	if ($_::TEST_MODE) {
		my $caller2 = join("\n", @caller);
		my $content = "$msg\n$caller2\n";
		my $length = length($content);
		print <<END;
Content-type: text/plain\r
Content-length: $length\r
Connection: close\r
\r
$content
END
	}
}

exit;
