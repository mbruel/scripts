#!/usr/bin/perl
use strict;
use vars qw/
@PORTS $openIpFile
$newIp $newNetwork $oldIp $oldNetwork
@ips $port $cmd
$debug
$IPTABLES $IPTABLE_USER
/;

$debug=0;

$IPTABLES='/sbin/iptables';

$IPTABLE_USER = 'mb'; # User that has sudo iptables (avoid to log as root)

# Previous IP that has ports open is stored in this File
$openIpFile='/home/mb/.openIP';

# Ports:
#   - 563  : nntp server
#   - 8080 : squid
#   - 8888 : stream movie via vlc
#   - 1194 : openvpn
@PORTS = qw/563 8080 8888 1194/;

# Script a user allowed to use iptables
die "You need to be logged as $IPTABLE_USER or root to use $0\n" if ($ENV{USER}!~/^root|$IPTABLE_USER$/);
$IPTABLES = "sudo $IPTABLES" if ($ENV{USER} eq $IPTABLE_USER);


# Check syntax
# First case: Change main IP
if ($#ARGV == 0){
	$newIp=$ARGV[0];
	if ($newIp !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$/ ){
		print "Wrong syntax: $newIp is not an IP\n\n";
		&syntax();
	} else {
		$newNetwork="$1.0";
		print "new Network: $newNetwork\n" if ($debug);
	}
}
# 2nd Case: list/add/del Ips for specific port
elsif ($#ARGV >= 2 ){
	&syntax() if ($ARGV[0]!~/^-p$/);

	$port=$ARGV[1];
	&syntax() if ($port!~/^\d+$/);

	$cmd=$ARGV[2];
	if ($cmd!~/^(list|add|del)$/){
		print "Wrong syntax: Bad command '$cmd'\n\n";
		&syntax();
	}

	if ($#ARGV>2){
		for (my $i=3; $i<=$#ARGV; ++$i){
			my $ip=$ARGV[$i];
			if ( $ip !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$/ ){
				print "Wrong syntax: Arg #$i is not an IP ($ip)\n\n";
				&syntax();
			} else {
				push(@ips, $ip);
			}
		}
	}
}
# Wrong syntax
else{
	&syntax();
}



# Syntax OK, Let's do the job!!!
# First case: Change main IP
if ( defined($newIp) ){
	# Check $openIpFile exist and contain the current IP in use with iptables rules
	if (! -e $openIpFile) {
		print "The file '$openIpFile' does not exist.\n";
		print "Please create it with the current main IP in use so it can be removed";
		exit 2;
	}

	# Read the Old Ip from the file
	open my $file, '<', $openIpFile || die "Error opening tieum's IP file: $openIpFile\n";
	$oldIp=<$file>;
	chomp $oldIp;
	close $file;

	# Check it is an IP
	if ( $oldIp !~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.\d{1,3}$/ ){
		print "The file '$openIpFile' doesn't contain an IP\n";
		print "Please make sure it contains the current main IP in use so it can be removed";
		exit 2;
	} else {
		$oldNetwork="$1.0";
		print "old Network: $oldNetwork\n" if ($debug);
	}

	# Check it is the one is use
	my $iptablesCmd = "$IPTABLES -L -v -n | grep $oldNetwork | wc -l";
	my $oldIpRuleNb=`$iptablesCmd`;
	print "Old Ip Rule number: $oldIpRuleNb\n" if ($debug);
	if ($oldIpRuleNb == 0){
		print "There are no iptables rules with the old IP: $oldIp (network: $oldNetwork)\n";
		print "Please update the file '$openIpFile' with the old ip in use and rerun the script\n";
		print "It must be one of these one:\n";

		# Let's use the last port to grep iptables and find the potential current main IP
		$iptablesCmd="$IPTABLES -L -n -v |grep $PORTS[$#PORTS]";
		print "Cmd: $iptablesCmd\n" if ($debug);
		system($iptablesCmd);
		exit 3;
	}


	# All good, let's remove the old ip, and add the new one!
	print "Main Ip mode: replace the main IP $oldIp by the new one: $newIp\n";
	for (my $i=0; $i<=$#PORTS; ++$i){
		my $removeOldIpForPort="$IPTABLES -D INPUT -p TCP -s $oldIp/24 --dport $PORTS[$i] -j ACCEPT";
		print "$removeOldIpForPort\n" if ($debug);
		system($removeOldIpForPort);

		my $addNewIpForPort="$IPTABLES -A INPUT -p TCP -s $newIp/24 --dport $PORTS[$i] -j ACCEPT";
		print "$addNewIpForPort\n" if ($debug);
		system($addNewIpForPort);
	}


	# Show the rules inserted
	print "Rules inserted:\n";
	$iptablesCmd="$IPTABLES -L -v -n | grep $newNetwork";
	print "$iptablesCmd\n";
	system($iptablesCmd);


	# Update the new main IP in the file openIpFile
	my $updateTieumIP="echo $newIp > $openIpFile";
	system($updateTieumIP);
}


# 2nd Case: list/add/del Ips for specific port
else {
	print "Cmd: $cmd, port: $port, ips: @ips\n" if ($debug);

	if ($cmd eq 'list'){
		my $listIpForPort="$IPTABLES -L -v -n | grep $port";
		print "$listIpForPort\n";
		system($listIpForPort);
	} else {
		if ($#ips < 0){
			print "Wrong syntax: $cmd Ips but no ips were given...\n\n";
			&syntax();
		} else {
			my $cmd2;
			if ($cmd eq 'add'){
				$cmd2='A';
			} else{
				$cmd2='D';
			}

			foreach my $ip (@ips){
				my $iptablesCmd="$IPTABLES -$cmd2 INPUT -p TCP -s $ip --dport $port -j ACCEPT";
				print "$iptablesCmd\n";
				system($iptablesCmd);
			}
		}
	}
}


exit 0;


sub syntax(){
	my $ports=join(',',@PORTS);
	print <<__SYNTAX__;
$0 is an easy interface to add/remove IPs from iptables rules.
Two different syntax:
\t- $0 -p <port> [list|add|del] (<IP> )*
\t- $0 <new main IP>
To use the second option, make sure that the file '$openIpFile' exists and contains the main IP in use
i.e: that has all the main ports open ($ports)
__SYNTAX__

	exit 1;
}

