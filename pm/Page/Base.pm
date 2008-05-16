package Page::Base;

=pod
----------------------------------------------------------------------
基本機能のページ処理
----------------------------------------------------------------------
=cut

use strict;
use MobaConf;
use HTMLTemplate;
use Common;
use Response;

#-----------------------------
# サポート外機種の場合 

sub pageNoSupport {
	my $rhData = {};
	my $html = HTMLTemplate::insert('base/nosup', $rhData);
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# proxy 経由の場合の場合 

sub pageNoProxy {
	my $rhData = {};
	my $html = HTMLTemplate::insert('base/noprx', $rhData);
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# UID 非通知設定の場合

sub pageNoUID {
	my $rhData = {};
	my $html = HTMLTemplate::insert('base/nouid', $rhData);
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# 会員登録必須画面（ようこそ画面）

sub pageWelcome {
	my $rhData = {};
	my $html = HTMLTemplate::insert('base/welcome', $rhData);
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# サービスステータス不適合の場合

sub pageServSt {
	my $func = shift;
	my $rhData = {};
	
	my $page = '';
	if      ($_::U->{SERV_ST_ERR} & 1) { # 自主退会
		$page = 'serv1';
	} elsif ($_::U->{SERV_ST_ERR} & 2) { # 運用退会
		$page = 'serv2';
	} elsif ($_::U->{SERV_ST_ERR} & 4) { # PENALTY
		$page = 'serv4';
	} elsif ($_::U->{SERV_ST_ERR} & 8) { # メール不達
		$page = 'serv8';
	}
	my $html = HTMLTemplate::insert("base/$page", $rhData);
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# not found

sub page404 {
	my $rhData = {};
	my $html = HTMLTemplate::insert('base/404', $rhData);
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# 静的 HTML

sub pageStatic {
	my $func = shift;
	my $rhData = {};
	
	my $page = $_::F->{page};
	
	if ($page =~ /\.\./ || $page =~ /[^\da-z\.\/\-\_]/i) {
		die "Invalid Page Access '$page'\n";
	}
	
	$page .= 'index.html' if ($page =~ m#/$#);
	$page  = $`           if ($page =~ m#\.html$#);
	
	my $html = HTMLTemplate::insert("../_html/$page", $rhData);
	
	if ($html ne '') {
		Response::output(\$html);
	} else {
		MException::throw({ CHG_FUNC => '.404' });
	}
}

######################################################################
#
#        以下は、Main.pm からイレギュラーな呼び方をされる

#-----------------------------
# POST でリダイレクトが必要になった場合の中継画面

sub pageRedirect {
	my $rhData = {};
	
	$rhData->{Func} = ($_::F->{f} ne '') ? "_$_::F->{f}" : '';
	
	my $rhHidden = Common::cloneHash($_::F, '^[^_]');
	delete($rhHidden->{f});
	delete($rhHidden->{uid});
	delete($rhHidden->{sid});
	delete($rhHidden->{guid});
	$rhData->{Hidden}  = Common::makeHidden($rhHidden);
	
	$rhData->{BaseURL} = $ENV{MB_SSL} ?
		Request::makeSSLBasePath() :
		Request::makeBasePath();
	my $html = HTMLTemplate::insert('base/redirect', $rhData);
	
	Response::output(\$html, 'no-cache');
}

#-----------------------------
# エラー画面

sub pageError {
	my $e = shift;
	
	if ($_::TEST_MODE) {
		my $debug_msg = MException::makeMsg($e). "\n\n";
		my @caller;
		for my $ref (reverse @Util::DIE::CALLER) {
			my ($file, $line) = @{$ref}[1,2];
			my $home_expr = quotemeta($_::HOME_DIR). "/?";
			$file =~ s/^$home_expr//;
			$debug_msg .= "$file:$line\n";
		}
		$e->{DEBUG_MSG} = $debug_msg;
	}
	
	my $html = HTMLTemplate::insert('base/error', $e);
	
	Response::output(\$html, 'no-cache');
}


1;
