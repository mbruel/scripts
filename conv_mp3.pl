#!/usr/bin/perl
use strict;

#my $audioQuality='192';
my $audioQuality='256';
#my $audioQuality='320';

my $path='./';


# More useful to have the bitrate
die "syntax: $0 <bitrate>?\n" if ($#ARGV>0);
if ($#ARGV == 0){
	my $bitrate=$ARGV[0];
	$audioQuality=$bitrate if ($bitrate=~/(128|192|256|320)/);
}
print "Bitrate: $audioQuality\n";

opendir my $dir, $path || die "couldn't open dir: $path\n";
while (my $f = readdir($dir)){
	if ($f=~/^(.*)\.(flac|wav)$/i){
		my $track=$1;
		my $cmd="ffmpeg -i \"$f\" -vn -acodec libmp3lame -ab ${audioQuality}k \"$track.mp3\"";
		print "- $cmd\n";
		system($cmd);
	}
}
closedir $dir;

exit 0;
