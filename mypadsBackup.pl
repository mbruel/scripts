#!/usr/bin/perl
###########################################################################
# Export Pads from etherpads mypads plugin                                #
#                                                                         #
# cf https://framagit.org/framasoft/Etherpad/ep_mypads/-/issues/249       #
###########################################################################
use strict;
use JSON;
use Data::Dumper;
use vars qw/
%htaccess %myPads
$curl $dstPath
$format %exportTag
$debug
/;
$format = 'md';
%htaccess = (login => 'htaccessUSER', pass => 'htaccessPASS');
%myPads = (login => 'mypadsLOGIN', pass => 'mypadsPASS', url => 'https://mypads.myserver.fr/',
	pads => ['myPad-someID1', 'myPad2-someID2', 'myPad3-someID3']
);
$dstPath = '/tmp/pads';
$curl = '/usr/bin/curl';
$debug = 1;

%exportTag = (txt => 'txt', md => 'markdown', html => 'html', etherpad => 'etherpad');
if (!exists($exportTag{$format})){
	print "Error on the export format...\n";
	exit 2;
}

print "Pad export (in $format) to $dstPath from $myPads{url} using login: $myPads{login}\n";

#curl --basic --user htaccessUSER:htaccessPASS -X POST -H "Content-Type: application/json"  -d '{"login":"mypadsLOGIN","password":"mypadsPASS"}'  https://mypads.myserver.fr/mypads/api/auth/login
my $cmd = "$curl --silent";
$cmd .= " --basic --user $htaccess{login}:$htaccess{pass}" if (exists($htaccess{login}));
$cmd .= ' -X POST -H "Content-Type: application/json"';
$cmd .= " -d '{\"login\":\"$myPads{login}\",\"password\":\"$myPads{pass}\"}'";
$cmd .= " $myPads{url}mypads/api/auth/login";

my $jsonStr = `$cmd`;
my $json = decode_json($jsonStr);
if (!exists($json->{token})){
	print "Error getting Auth Token using url: $cmd\n$jsonStr\n";
	exit 1;
}
elsif ($debug){
	print Dumper $json;
	print "Auth Token: $json->{token}\n";
}

#curl --basic --user htaccessUSER:htaccessPASS  https://mypads.myserver.fr/p/myPad-someID/export/txt?auth_token=someToken
foreach my $pad (@{$myPads{pads}}){
	$cmd = "$curl --silent";
	$cmd .= " --basic --user $htaccess{login}:$htaccess{pass}" if (exists($htaccess{login}));
	$cmd .= " $myPads{url}p/$pad/export/$exportTag{$format}?auth_token=$json->{token}";
	$cmd .= " > $dstPath/$pad.$format";

	system($cmd);
	if ($? == 0) {
		print "- pad: $pad exported";
		print " (cmd: $cmd)" if ($debug);
		print "\n";
	} else {
		print "ERROR exporting pad $pad with cmd $cmd..\n";
	}
}

exit 0;
