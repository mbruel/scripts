#!/usr/bin/perl
use strict;
use Getopt::Std;

use vars qw/
$prefix $scale $rot $v_codec $a_codec $v_rot
$do_scaling $max_width $max_height $do_compress $do_rotate
$bitrate $bitrate_default
$fileName_videoList
$debug
/;

$debug       = 0;
$do_compress = 0;
$do_scaling  = 0;
$do_rotate   = 0;


$max_width       = 720;
$max_height      = 640;
$v_codec         = '-c:v h264';
$bitrate_default = '1M';
$a_codec         = '-c:a mp3 -ab 96k';
$prefix          = '';
$v_rot           = '-vf "transpose=1"';


&getOptions();
$v_codec.=" -b $bitrate";


if (!($do_compress || $do_scaling || $do_rotate)){
	print "No actions are selected (scaling and/or compression)\n";
	print "No job to do...\n\n";
	exit -1;
}


if (!$do_compress){
	$v_codec = '';
	$a_codec = '-c:a copy';
} else {
	$prefix .= 'compressed';
}

$prefix .= '_scaled' if ($do_scaling);
$prefix .= '_rot'    if ($do_rotate);

=pod
my @vids = (
	'./7.Planet.Earth.EP07.Great.Plains/Planet.Earth.07.Great.Plains.2006.1080p.HDDVD.x264.anoXmous_.mp4',
	'./8.Planet.Earth.EP08.Jungles/Planet.Earth.08.Jungles.2006.1080p.HDDVD.x264.anoXmous_.mp4',
	'./9.Planet.Earth.EP09.Shallow.Seas/Planet.Earth.09.Shallow.Seas.2006.1080p.HDDVD.x264.anoXmous_.mp4',
	'./10.Planet.Earth.EP10.Seasonal.Forests/Planet.Earth.10.Seasonal.Forests.2006.1080p.HDDVD.x264.anoXmous_.mp4',
	'./11.Planet.Earth.EP11.Ocean.Deep/Planet.Earth.11.Ocean.Deep.2006.1080p.HDDVD.x264.anoXmous_.mp4'
);

foreach my $vid (@vids){
	&do_ffmpeg($vid);
}
=cut


open my $listVideo, '<', $fileName_videoList || die "can't read file $fileName_videoList\n";
while (my $vid = <$listVideo>){
	chomp($vid);
	&do_ffmpeg($vid);
}
close($listVideo);

exit 0;


sub do_ffmpeg(){
	my $vid = shift;

	if ( ($vid =~ /^(.*)\.(mp[4g]|mov)$/i) && (-f $vid && -r $vid) ){
		my $output = $1;
		if ($output =~ /\//){
			$output = `basename $output`;
			chomp($output);
		}
		print "- VIDEO: $vid\n";
		my ($width, $height) = split(' ', &get_video_format($vid));
		print "format: ($width, $height)\n";

		if ($do_scaling){

			$scale = '';
			if ($width > $height) {
				if ($width > $max_width) {
					my $ratio = $width/$height;
					$height   = int($max_width / $ratio);

					# height needs to be a multiple of 4
					my $modulo = $height % 4;
					if ($modulo == 3){
						++$height;
					} else {
						$height -= $modulo;
					}

					$scale   = "-vf scale=${max_width}x$height";
				}
			} else {
				if ($height > $max_height){
					my $ratio = $height/$width;
					$width   = int($max_height / $ratio);

					# height needs to be a multiple of 4
					my $modulo = $width % 4;
					if ($modulo == 3){
						++$width;
					} else {
						$width -= $modulo;
					}

					$scale   = "-vf scale=${width}x$max_height";
				}
			}
		}

		# No need to do the scaling
		if ($do_scaling && ($scale eq '') ){
			print "No need of scaling (max_width, max_height)=($max_width, $max_height)\n";
			if (!$do_compress){
				print "As there is no compression, NO JOB at all\n\n\n\n\n\n";
				return 0;
			}
		}

		if ($do_rotate){
			$rot = $v_rot;

		} else {
			$rot = '';
		}

		my $cmd = "ffmpeg -i \"$vid\" $rot $v_codec $scale $a_codec \"${prefix}_$output.mp4\"";
		print "=> CMD: $cmd\n";
		system($cmd) if (!$debug);
		print "\n\n\n\n\n";

	} else {
		print "ERROR: file '$vid' is not a video or is not accessible or readable...\n";
	}
}


sub get_video_format() {
	my $vid_path = shift;
	my $dim = '';

	#width=720
	my $ffprobe = `ffprobe -i \"$vid_path\" -show_streams 2>/dev/null | grep width`;
	chomp($ffprobe);
	my @res=split('=',$ffprobe);
	$dim.=$res[1] if ($#res == 1);

	#height=416
	$ffprobe = `ffprobe -i \"$vid_path\" -show_streams 2>/dev/null | grep height`;
	chomp($ffprobe);
	my @res=split('=',$ffprobe);
	$dim.=" $res[1]" if ($#res ==1);

	return $dim;
}

sub getOptions(){
	my %options=();
	if (! getopts("dcb:srf:", \%options) ) {
		&syntax();
		exit -1;
	}

	$debug       = 1 if defined $options{d};
	$do_compress = 1 if defined $options{c};
	$do_scaling  = 1 if defined $options{s};
	$do_rotate   = 1 if defined $options{r};
	if (! defined($options{f}) ){
		print "ERROR: you need to provide a file containing the list of videos\n\n";
		&syntax();
		exit -1;
	}

	$fileName_videoList = $options{f};
	if (! (-f $fileName_videoList && -r _) ){
		print "ERROR: can't read file: $fileName_videoList\n\n";
		&syntax();
		exit -1;
	}

	if (defined($options{b})){
		$bitrate = $options{b};
		if ($bitrate !~ /^[1-5]M$/){
			&syntax();
			exit -1;
		}
	} else {
		$bitrate = $bitrate_default;
	}

}


sub syntax(){
	print<<__TXT__;
Syntax: $0 (-d)? (-c)? (-b [1-5]M)? (-s)? (-r)? -f <file_name of list of videos>

    -c: compress video (settings hardcoded: v_codec: $v_codec -b ${bitrate_default}M, a_codec: $a_codec)
    -b: change the default compression bitrate
    -s: scale the video using hardcoded max_width: $max_width
    -r: rotate video (portrait taken with phone but stored as landscape) cmd: $v_rot
    -d: debug mode or dry mode: prints ffmpeg commands but doesn't execute them
    -f <file_name>: text file containing the list of videos to compress (absolute or relative paths)

__TXT__
}
