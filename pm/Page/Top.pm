package Page::Top;

use strict;
use MobaConf;
use Common;
use HTMLTemplate;
use Response;
use DA;

#-----------------------------------------------------------
# トップページ 

sub pageMain {
	my $func = shift;
	my $rhData = {};
	
	my $html = HTMLTemplate::insert("top/top", $rhData);
	Response::output(\$html);
}

1;
