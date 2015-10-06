#!/bin/bash

wipeCmd='time dd if=/dev/zero of=/dev/sda4 bs=1M'
#wipeCmd='ls'

function wipe(){
	echo ""
	echo "     /!\\ You're about to wipe the data partition /!\\"
	echo ""
	echo "Cmd: $wipeCmd"
	echo ""
	respOk=0
	while [ $respOk == 0 ]; do
		read -n1 -p "Are you sure you want to do this? [yN] "
		case $REPLY in
			y | Y)
				echo ""
				echo "You want to proceed..."
				respOk=1
				;;
			n | N | '')
				echo ""
				echo "You want to skip..."
				respOk=1
				;;
			* )
				echo ""
				;;
		esac
	done

	#http://stackoverflow.com/questions/2264428/converting-string-to-lower-case-in-bash-shell-scripting
	if [ "${REPLY^^}" == "Y" ] ; then
		respOk=0
		echo""
		while [ $respOk == 0 ]; do
			read -n1 -p "REALLY SURE? [yN] "
			case $REPLY in
				y | Y)
					echo ""
					echo "You REALLY want to proceed..."
					respOk=1
					;;
				n | N | '')
					echo ""
					echo "You want to skip..."
					respOk=1
					;;
				* )
					echo ""
					;;
			esac
		done

	else
		return 0
	fi


	if [ "${REPLY^^}" == "Y" ] ; then
		$wipeCmd

		echo ""
		echo ""
		echo "Job has been done with the command: $wipeCmd"
		return 1
	else
		return 0
	fi
}

wipe
exit 0
