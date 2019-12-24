#!/usr/bin/perl
# Update director in DB for all movies fetching it on themoviedb.org
#

use strict;
use LWP::UserAgent;
use DBI;
use utf8;
use vars qw/%DB %SQL $movieDB $ua $debug $sleep $idStart $useTOR/;

$useTOR  = 1;
if ($useTOR){
	use LWP::Protocol::socks; # make sure the module is installed...
	#if not:
	# perl -MCPAN -e shell
	# install LWP::Protocol::socks
	#
	# or on windows: cpanm LWP::Protocol::socks
}


$idStart = 0;
$debug   = 1;
$sleep   = 0;

%DB = ( host => 'localhost', port => 3306, user => 'MY_USER', pass => 'MY_PASS', db => 'MY_DB');
%SQL = (
	getMoviesIDs   => "select id, tmdbid, title from site_tmdb where type = \"MOVIE\"  and id > $idStart order by id;",
	updateDirector => 'update site_tmdb set realisateur=? where tmdbid=?;'
);

$movieDB = 'https://www.themoviedb.org/movie/';


$ua = LWP::UserAgent->new;
$ua->proxy([qw/ http https /] => 'socks://localhost:9050') if ($useTOR); # Tor proxy

my $dbh = DBI->connect("dbi:mysql:database=$DB{db};host=$DB{host};port=$DB{port}", $DB{user}, $DB{pass},
	{AutoCommit=>1, RaiseError=>1, PrintError=>0, mysql_enable_utf8 => 1} ) or die "Can't connect to the Database...\n";

#print "req: $SQL{getMoviesIDs}\n";
my $sth_movies = $dbh->prepare($SQL{getMoviesIDs});
my $sth_update = $dbh->prepare($SQL{updateDirector});
$sth_movies->execute();
my $nbMovies = $sth_movies->rows;
print "Number of movies to process: $nbMovies\n";
for (my $i=0; $i<$nbMovies; ++$i){
	my $res     = $sth_movies->fetchrow_hashref();
	my $tmdbid  = $res->{tmdbid};
	my @directors;
	if ($debug) {
		my $num = $i + 1;
		print "[$num/$nbMovies] Processing $res->{title} (id: $res->{id}, tmdbid: $tmdbid)\n";
	}
	&getDirectorFromMovieDB($tmdbid, \@directors);
	if ($#directors != -1)
	{
		my $realisateur = '[';
		for my $director (@directors)
		{
#			$director->{name} =~ tr/ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ/aaaaaaaaaaaaooooooooooooeeeeeeeecciiiiiiiiuuuuuuuuynn/;
			print "\t -> Director found: $director->{name}, id: $director->{id}\n" if ($debug);
			$realisateur .= '{"id":'.$director->{id}.',"name":"'.$director->{name}.'"},';
		}
		chop($realisateur); # remove last coma
		$realisateur .= ']';
		utf8::encode($realisateur) if (!utf8::valid($realisateur));
		$sth_update->execute($realisateur, $tmdbid) || print "ERROR updating DB...\n";
	}
	sleep($sleep) if ($sleep > 0);
}
$sth_update->finish();
$sth_movies->finish();
$dbh->disconnect();
exit 0;


sub getDirectorFromMovieDB()
{
	my ($movieID, $directors) = @_;

	my $req = HTTP::Request->new(GET => $movieDB.$movieID.'/cast');
	my $res = $ua->request($req);
	if ($res->is_success) {
		open my $fh, '<:encoding(UTF-8)', \$res->content or die $!;
		my $directorFound = 0;
		my $line; # arrive to the director section '<h4>Directing</h4>'
		do { $line = <$fh>; } while ($line && $line !~ /^\s*<h4>Directing<\/h4>\s*/);

		if ($line)
		{
			while ($line = <$fh>) {
				chomp $line;
#				utf8::decode($line);
				#<p><a href="/person/138-quentin-tarantino">Quentin Tarantino</a></p>
				if ($line =~/^\s*<p><a href="([^"]*)">(.+)<\/a><\/p>\s*$/){
					my ($link, $person) = ($1, $2);
					<$fh>;<$fh>; # skip 2 lines
					$line = <$fh>;
					if ($line =~ /^\s*Director(,.*)?\s*\n$/) {
						my $id = $1 if ($link =~/^\/person\/(\d+)(-.*)?$/);
#						print "$person : $id ($link)\n";
						push(@$directors, {name => $person, id => $id});
						$directorFound    = 1;
#						last;
					}
				}
			}
		}

		print "\tNO_UPDATE: Couldn't find the director...\n" if ($debug && !$directorFound);
		close $fh or die $!;
		return 1;
	}
	else {
		print 'Failed getting movie "'.$movieDB.$movieID.'/cast" : '.$res->status_line."\n";
		return 0;
	}
}
