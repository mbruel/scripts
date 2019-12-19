#!/usr/bin/perl
# Get the director of a movie on themoviedb by giving its ID
#

use strict;
use LWP::UserAgent;
use vars qw/$movieDB $movieID/;

die "Syntax: $0 <movieDB_ID>\n" if ($#ARGV != 0);

$movieDB = 'https://www.themoviedb.org/movie/';
$movieID = $ARGV[0];

my $ua = LWP::UserAgent->new;
my $req = HTTP::Request->new(GET => $movieDB.$movieID.'/cast');
my $res = $ua->request($req);
if ($res->is_success) {
	open my $fh, '<', \$res->content or die $!;

	my $line; # arrive to the director section '<h4>Directing</h4>'
	do { $line = <$fh>; } while ($line !~ /^\s*<h4>Directing<\/h4>\s*/);

	while (my $line = <$fh>) {
		chomp $line;
		#<p><a href="/person/138-quentin-tarantino">Quentin Tarantino</a></p>
		if ($line =~/^\s*<p><a href="([^"]*)">(.+)<\/a><\/p>\s*$/){
			my ($link, $person) = ($1, $2);
			<$fh>;<$fh>; # skip 2 lines
			$line = <$fh>;
			if ($line =~ /^\s*Director\s*\n$/) {
				my $id = $1 if ($link =~/^\/person\/(\d+)(-.*)$/);
				print "$person : $id ($link)\n";
				last;
			}
		}
	}
	close $fh or die $!;
}
else {
	print 'Failed getting movie "'.$movieDB.$movieID.'/cast" : '.$res->status_line."\n";
}
exit 0;
