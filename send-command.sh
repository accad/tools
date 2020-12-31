#!/bin/bash
#
# send-command.sh
# Nick Accad <naccad@gmail.com>
# 2018
#

function runTesting() {
	echo $argValue
	echo $CombinedFile
	echo $HostsFile
	echo $Username
	echo $Password
	echo $ScriptToSend
}


function runSimpleScript() { 
	chmod 755 $ScriptToSend
	for host in `cat $HostsFile`
	do
		echo -n "Working on $host..."
		sshpass -p $Password scp -o StrictHostKeyChecking=no $ScriptToSend root@$host:/tmp/$ScriptToSend
		sshpass -p $Password ssh -o StrictHostKeyChecking=no root@$host /tmp/$ScriptToSend
		echo "DONE"
	done
}

function runCombinedScript() {
	echo chmod 755 $ScriptToSend
	for line in `cat $CombinedFile`
	do
		host=`echo $line | cut -d , -f 1`
		user=`echo $line | cut -d , -f 2`
		pass=`echo $line | cut -d , -f 3`

		echo -n "Working on $host..."
		sshpass -p $pass scp -o StrictHostKeyChecking=no $ScriptToSend root@$host:/tmp/$ScriptToSend
		sshpass -p $pass ssh -o StrictHostKeyChecking=no root@$host /tmp/$ScriptToSend
		echo "DONE"
	done
}

function usage() {
	echo
	echo "$0 -u USERNAME -p PASSWORD -f HOSTS_FILE -s SCRIPT_TO_SEND"
	echo "$0 -c COMBINED_FILE -s SCRIPT_TO_SEND"
	echo 
	echo "- Sends a script file to a Unix host via scp to /tmp, and then executes that file on the remote host"
	echo "- HOSTS_FILE contains a list of hosts to excute this against, one per line"
	echo "- COMBINED_FILE is a CSV with HOST,USERNAME,PASSWORD format"
	echo "- Requires a copy of SSHPASS available in \$PATH https://sourceforge.net/projects/sshpass/"
	echo
	echo "Nick Accad <naccad@gmail.com> 2018"
	echo 
}

ArgValue=0
useFunction='runSimple'

while [[ $# -gt 0 ]]
do
	key="$1"
	case "$key" in
		-h|--help)
			usage
			ArgValue=0
			exit 0
			;;
		-u|--username)
			Username=$2
			((ArgValue++))
			shift
			;;
		-p|--password)
			Password=$2
			((ArgValue++))
			shift
			;;
		-f|--hosts)
			HostsFile=$2
			((ArgValue++))
			shift
			;;
		-s|--script)
			ScriptToSend=$2
			((ArgValue+=6))
			shift
			;;
		-c|--combined)
			useFunction='runCombined'
			CombinedFile=$2
			((ArgValue+=3))
			shift
			;;
		-d|--testing)
			useFunction='runTesting'
			((ArgValue+=3))
			shift
			;;
		*)
			echo
			echo "ERROR: Unknown Parameter $1"
			usage
			exit 1
			;;

	esac
	shift
done

if [[ $ArgValue -ne 9 ]]
then
	echo
	echo "ERROR, invalid number of arguments"
	usage
	exit 1
fi

case "$useFunction" in
	runSimple)
		runSimpleScript
		;;
	runCombined)
		runCombinedScript
		;;
	runTesting)
		runTesting
		;;
esac

