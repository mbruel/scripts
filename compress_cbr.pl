#!/usr/bin/perl
use strict;
use Cwd;
use vars qw/$MOVE_FILES/;

$MOVE_FILES = 'find %s -type f -exec file {} \; | cut -d\':\' -f1 | xargs -I{} mv {} .';

=pod
This script is for Unix environment.
It uses CompressCbr.java (that you can find in my Java repository)
It will compress all the cbr or cbz of the local folder using the CompressCbr.java
Unrar is required to extract cbr.
The output is a cbz (zip is used). The initial archive is not deleted.
=cut


my $path = getcwd;
print "Local Path: $path\n";


opendir my $dir, '.' || die "can't open folder";
while (my $file = readdir($dir)){
	if ($file =~ /^(.*)\.(cbr|cbz)/i){
		my ($name, $ext) = ($1, $2);
		print "- $file\n";

		# Create temp folder
		my $cmd = "mkdir \"$name\"";
		&doCmd($cmd);

		# Jump in the folder and extract
		chdir("$path/$name") || die "Issue chdir $path/$name";
		my $output = $name;
		if ($ext =~ /cbr/i){
			$cmd = 'unrar x ';
		} else {
			$cmd = 'unzip ';
			$output.='_compressed';
		}
		$cmd.="../\"$file\"";
		&doCmd($cmd);

		&moveFilesFromIntermediateFolders("$path/$name");

		# Get back to main folder and launch the compression
		chdir($path);
		&doCmd("java CompressCbr \"$name\"");


		# Remove temp folder and rename the compressed one
		&doCmd("rm -r \"$name\"");
		&doCmd("mv \"compress_$name\" \"$name\"");
		&doCmd("zip -r \"$output.cbz\" \"$name\"");
		&doCmd("rm -r \"$name\"");
	}
}
closedir $dir;

exit 0;


sub doCmd(){
	my $cmd = shift;
	print "\t$cmd\n";
	system($cmd);
}


sub moveFilesFromIntermediateFolders() {
	my $path = shift;


	my $path = getcwd;
	print "[moveFiles] Local Path: $path\n";

	opendir my $dir, '.';
	while (my $f = readdir($dir)){
		if ( ($f !~ /^\.{1,2}$/) && -d $f){
			print "There is an intermediate Folder $f\n";

			# Move the files
			my $mvCmd = sprintf($MOVE_FILES, $f);
			&doCmd("$mvCmd");

			# Delete the folder
			&doCmd("rm -r $f");
		}
	}
	closedir($dir);
}
