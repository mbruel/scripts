#!/usr/bin/perl
# Update director in DB for all movies fetching it on themoviedb.org
#

use strict;
use LWP::UserAgent;
use DBI;
use utf8;
use vars qw/%DB %SQL $movieDB $ua/;

%DB = ( host => 'localhost', port => 3306, user => 'MY_USER', pass => 'MY_PASS', db => 'MY_DB');
%SQL = (
	getMoviesIDs   => 'select tmdbid from site_tmdb where type = "MOVIE";',
	updateDirector => 'update site_tmdb set realisateur=? where tmdbid=?;'
);

$movieDB = 'https://www.themoviedb.org/movie/';


$ua = LWP::UserAgent->new;

my $dbh = DBI->connect("dbi:mysql:database=$DB{db};host=$DB{host}", $DB{user}, $DB{pass}, 
	{AutoCommit=>1, RaiseError=>1, PrintError=>0, mysql_enable_utf8 => 1} ) or die "Can't connect to the Database...\n";

#print "req: $SQL{getMoviesIDs}\n";
my $sth_movies = $dbh->prepare($SQL{getMoviesIDs});
my $sth_update = $dbh->prepare($SQL{updateDirector});
$sth_movies->execute();
my $nbMovies = $sth_movies->rows;
print "Number of movies $nbMovies\n";
for (my $i=0; $i<$nbMovies; ++$i){
	my $res     = $sth_movies->fetchrow_hashref();
	my $tmdbid  = $res->{tmdbid};
	my %director;
	&getDirectorFromMovieDB($tmdbid, \%director);
	if (defined($director{name}))
	{
#		$director{name} =~ tr/ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ/aaaaaaaaaaaaooooooooooooeeeeeeeecciiiiiiiiuuuuuuuuynn/;
#		print "Director: $director{name}, id: $director{id}\n";
		my $realisateur = '{"id":'.$director{id}.',"name":"'.$director{name}.'"}';
		utf8::encode($realisateur);
		$sth_update->execute($realisateur, $tmdbid);
	}
}
$sth_update->finish();
$sth_movies->finish();
$dbh->disconnect();
exit 0;


sub getDirectorFromMovieDB()
{
	my ($movieID, $director) = @_;

	my $req = HTTP::Request->new(GET => $movieDB.$movieID.'/cast');
	my $res = $ua->request($req);
	if ($res->is_success) {
		open my $fh, '<', \$res->content or die $!;

		my $line; # arrive to the director section '<h4>Directing</h4>'
		do { $line = <$fh>; } while ($line !~ /^\s*<h4>Directing<\/h4>\s*/);

		while (my $line = <$fh>) {
			chomp $line;
			utf8::decode($line);
			#<p><a href="/person/138-quentin-tarantino">Quentin Tarantino</a></p>
			if ($line =~/^\s*<p><a href="([^"]*)">(.+)<\/a><\/p>\s*$/){
				my ($link, $person) = ($1, $2);
				<$fh>;<$fh>; # skip 2 lines
				$line = <$fh>;
				if ($line =~ /^\s*Director\s*\n$/) {
					my $id = $1 if ($link =~/^\/person\/(\d+)(-.*)?$/);
#					print "$person : $id ($link)\n";
					$director->{name} = $person;
					$director->{id}   = $id;
					last;
				}
			}
		}
		close $fh or die $!;
	}
	else {
		print 'Failed getting movie "'.$movieDB.$movieID.'/cast" : '.$res->status_line."\n";
	}
}
