#!/usr/bin/perl
# Recursive scan of the folder given in parameter
# Parse all files with the given extension
#   Look for all the include statement
#     check if they exists
#     if not check if one with a matching case exists
#       if so, rewrite the file
#
# by M. Bruel, v1.0
# TODO: could also check the case of the folders
use strict;
use vars qw/
$extensionFiles
$regExpInclude $regExpQtUi
$pathGlobal
$debug
$do_rename
$isQtProject
/;

$extensionFiles = '(h|cpp)';
$regExpInclude  = '^\s*#include\s+"([\.\/\w]+\.h)"';

$regExpQtUi     = '^ui_(.*)\.h$';
$isQtProject    = 1;

$debug          = 1;
$do_rename      = 0;


die "Syntax: $0 <path containing files>\n"if ($#ARGV != 0);
$pathGlobal = $ARGV[0];

die "Error: $pathGlobal is not a folder...\n" if (! -d $pathGlobal);

chop($pathGlobal) if ($pathGlobal =~ /\/$/);
&scanFolder($pathGlobal);

exit 0;


sub scanFolder(){
	my $path = shift;
	print "Processing path: $path\n";
	opendir my $DIR, $path || die "Error opening path: $path\n";
	# read dir with files first
	my @filesInDir = sort { -d $a <=> -d $b } readdir($DIR);

	foreach my $f (@filesInDir) {
		my $fp = "$path/$f";
#		print "file: $f, path: $fp\n";
		if (-f $fp and ($f =~ /^(.*)\.$extensionFiles$/) ){
			my ($file, $ext) = ($1, $2);
			&processFile($file, $ext, $path, \@filesInDir);
		} elsif (-d $fp and ($f !~ /^\.{1,2}$/) ){
			&scanFolder($fp);
		}
	}
	closedir $DIR;
	print "\n";
}


sub processFile(){
	my ($f, $ext, $path, $filesInDir)=@_;
	my $fp = "$path/$f.$ext";
	print "\t- $fp\n";
	open my $fh_old, '<', $fp       or die "Error opening file $fp\n";
	open my $fh_tmp, '>', "$fp.tmp" or die "Error creating file $fp.tmp\n";
	my $errorIncludeCase = 0;
	while (my $line = <$fh_old>){
		if ($line =~ /$regExpInclude/){
			my $inc = $1;
			print "\t\t- check include $inc\n" if ($debug);
			my $inc_good_case = &giveCorrectCase($inc, $path, $filesInDir);
			if ($inc_good_case eq ""){
				print "Error in file $fp: couldn't find include: $inc\n"
			} elsif ($inc_good_case eq $inc){
				print $fh_tmp $line;
			} else {
				print "Changing case from $inc to $inc_good_case\n";
				print $fh_tmp "#include \"$inc_good_case\"\n";
				$errorIncludeCase = 1;
			}
		} else {
			print $fh_tmp $line;
		}
	}
	close $fh_tmp;
	close $fh_old;

	my $cmd;
	if ($errorIncludeCase){
		$cmd = "mv $fp.tmp $fp";
		print "== $fp was modified! ==\n";
	} else {
		$cmd = "rm $fp.tmp"
	}

	system($cmd) if ($do_rename);
}


sub giveCorrectCase(){
	my ($inc, $path, $fileInCurrentDir) = @_;

	my @folders       = split /\//, $inc;
	my @filesInDir    = ();
	my $isCurrentPath = 0;
	my $pathRelative;

	if ($#folders == 0){ # include file is in local folder
		@filesInDir     = @$fileInCurrentDir;
		$isCurrentPath = 1;
	} else {
		$inc          = pop @folders; # pop the file name
		$pathRelative = join('/', @folders);

		if ($folders[0] eq '.'){ # relative path
			shift @folders;
			$path .= '/' . join('/', @folders);
		}elsif ($folders[0] eq '..'){ # relative path
			my @pathFolders = split /\//, $path;
			for (my $k=0; $k<=$#folders; ++$k){
				my $folder = $folders[$k];
				if ($folder eq '..'){
					pop @pathFolders;
				} else {
					push @pathFolders, $folder
				}
			}
			$path = join '/', @pathFolders;
		} else {
			$path .= '/' . join('/', @folders);

			# Try absolute path if from local doesn't exist
			if (! -e $path){ # if not relative path, try absolute one
				$path = $pathGlobal . '/' . join('/', @folders);
			}
		}

		print "\t\t\tLoading dir: $path\n" if ($debug);
		opendir my $DIR, $path || die "Error opening path: $path\n";
		while (my $f = readdir($DIR)){
			push @filesInDir, $f;
		}
#		@filesInDir = readdir($DIR) || die "Error reading path: $path\n";
		closedir $DIR;
	}

	my $isUi = 0;
	my $name = $inc;
	if ($isQtProject and $inc =~ /^ui_(.*)\.h$/){
		$name = "$1.ui";
		$isUi = 1;
	}
	for my $fileName (@filesInDir){
		print "check $fileName == $inc\n" if ($debug > 2);
		if ($name =~ /^$fileName$/i){
			if ($isUi){
				$fileName = substr $fileName, 0, -3;
				$fileName = "ui_$fileName.h";
				print "Ren UI: $fileName\n";
			}
			if ($isCurrentPath){
				return $fileName;
			} else {
				return  "$pathRelative/$fileName";
			}
		}
	}
	return "";
}

