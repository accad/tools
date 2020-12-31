#!/bin/bash
#
# Bash script to manipulate infoblox
#
# Nick Accad <naccad@gmail.com>
# 2019, 2020
#
#
# Update the location of the following binaries as needed
#
# curl is needed for everything
# jq and sed are needed for "update" and "delete" operations
#

####
#
#  Some sane values, you can override by putting VAR=value in ~/.iblox.conf
#
####

CURL=/usr/bin/curl
JQ=/usr/bin/jq
SED=/usr/bin/sed
GREP=/bin/grep

_VIEW=default
_API='2.6.1'
_USERNAME=admin
_PASSWORD=admin
_SERVER=infoblox

####

source ~/.iblox.conf

if [[ $DEBUG == 1 ]] 
then
	set -x
fi

function generate_json() {

	case "$1" in
		"reserve")
			cat <<EOF
{ "ipv4addrs": [ { "ipv4addr" : "func:nextavailableip:$_NETWORK" } ], "name": "$_FQDN", "view": "$_VIEW" }
EOF
			shift ;; 
		"add")
			cat <<EOF
{ "ipv4addrs": [ { "ipv4addr" : "$_IP" } ], "name": "$_FQDN", "view": "$_VIEW" }
EOF
			shift ;;
		"ip-update")
			cat <<EOF
{ "ipv4addrs": [ { "ipv4addr" : "$_IP" } ], "view": "$_VIEW" }
EOF
			shift ;;
		"fqdn-update")
			cat <<EOF
{ "name": "$_NFQDN", "view": "$_VIEW" }
EOF
			shift ;;

	esac
}

function usage() {
	echo
	echo "Infoblox WAPI script -- (c) Nick Accad <naccad@gmail.com> 2019-2020"
	echo
	echo "Required parameters:"
	echo 
	echo "  Globally:"
        echo "    -u/--username, -p/--password, --server, --op <OPERATION>"
	echo 
	echo "  Use --op help to get a list of operations"
	echo
	echo "  Operation Based:" 
	echo "    --ip (required for op=add|ip-update)"
	echo "    --fqdn (required for op=add|ip-update,fqdn-update,search-dns)"
        echo "    --network (required for op=reserve)"
	echo "    --new-fqdn (required for op=fqdn-update)"
	echo
	echo "Optional: --api ($_API), --view ($_VIEW)"
	echo
}

function get-grid() {
	URL="https://$_SERVER/wapi/v$_API/member?_return_fields%2b=upgrade_group,vip_setting"
	REF=$($CURL -s -k -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' $URL)
	#echo "$URL"
	echo "$REF"
}

function get-master() {
	URL="https://$_SERVER/wapi/v$_API/member?_return_fields%2b=upgrade_group,vip_setting"
	REF=$($CURL -s -k -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' $URL)
	echo $REF | $JQ '.[] | select(.upgrade_group=="Grid Master")' 
}

function add-host() { 
	if [[ -z "$_FQDN" ]]; then echo -e "\nERROR: Parameters missing"; exit 1; fi
	URL="https://$_SERVER/wapi/v$_API/record:host"
	BODY=$(generate_json add)
	REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X POST -H 'Content-Type: application/json' -d "$BODY" $URL)
	echo $REF
}

function update-host-ip() {
	if [[ -z "$_FQDN" ]]; then echo -e "\nERROR: Parameters missing"; exit 1; fi
	URL="https://$_SERVER/wapi/v$_API/record:host?name=$_FQDN"
	REF=$($CURL -s -k -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' $URL | $JQ .[]._ref | sed s/\"//g)
	#echo $URL
	URL="https://$_SERVER/wapi/v$_API/$REF" 
	BODY=$(generate_json ip-update)
	#echo CURL -s -k -u $_USERNAME:$_PASSWORD -X PUT -H 'Content-Type: application/json' -d "$BODY" $URL
	REF=$($CURL -s -k -u $_USERNAME:$_PASSWORD -X PUT -H 'Content-Type: application/json' -d "$BODY" $URL)
	echo $REF
}

function update-host-fqdn() {
	if [[ -z "$_FQDN" ]]; then echo -e "\nERROR: Parameters missing"; exit 1; fi
        URL="https://$_SERVER/wapi/v$_API/record:host?name=$_FQDN"
        REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' $URL | $JQ .[]._ref | sed s/\"//g)
        URL="https://$_SERVER/wapi/v$_API/$REF"
        BODY=$(generate_json fqdn-update)
        REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X PUT -H 'Content-Type: application/json' -d "$BODY" $URL)
        echo $REF
}

function reserve-host() { 
	if [[ -z "$_FQDN" ]]; then echo -e "\nERROR: Parameters missing"; exit 1; fi
	URL="https://$_SERVER/wapi/v$_API/record:host"
	BODY=$(generate_json reserve)
	REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X POST -H 'Content-Type: application/json' -d "$BODY" $URL)
	echo $REF
}

function delete-host() {
	if [[ -z "$_FQDN" ]]; then echo -e "\nERROR: Parameters missing"; exit 1; fi
        URL="https://$_SERVER/wapi/v$_API/record:host?name=$_FQDN"
        REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' $URL | $JQ .[]._ref | sed s/\"//g)
	URL="https://$_SERVER/wapi/v$_API/$REF"
	REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X DELETE -H 'Content-Type: application/json' -d "$BODY" $URL)
        echo $REF
}

function search-dns() { 
	if [[ -z "$_FQDN" ]]; then echo -e "\nERROR: Parameters missing"; exit 1; fi
	URL="https://$_SERVER/wapi/v$_API/record:host?name~=$_FQDN&view=$_VIEW"
	REF=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' $URL | $JQ .[]._ref | sed s/\"//g)
	for _url in $REF
	do
		URL="https://$_SERVER/wapi/v$_API/$_url"
		REFq=$($CURL -s -k1 -u $_USERNAME:$_PASSWORD -X GET -H 'Content-Type: application/json' -d "$BODY" $URL) 
		echo "$REFq" | $GREP -v "_ref"
	done
}


while [[ $# -gt 0 ]]
do
	key="$1"
	case "$key" in
		-u|--username)	_USERNAME=$2;	shift ;;
		-p|--password)	_PASSWORD=$2;	shift ;;
		--api)		_API=$2; 	shift ;;
		--server) 	_SERVER=$2; 	shift ;;
		--fqdn) 	_FQDN=$2; 	shift ;;
		--new-fqdn)	_NFQDN=$2;	shift ;;
		--ip)		_IP=$2;		shift ;;
		--network) 	_NETWORK=$2; 	shift ;; 
		--op) 		_OP=$2;		shift ;;
		--view)		_VIEW=$2;	shift ;; 
		-h|--help)	
			usage 
			exit 0	
			;;
		*)
			echo "$1 unknown"
			usage
			exit 1
			;;
	esac
	shift
done


if [[ -z "$_USERNAME" || -z "$_PASSWORD" || -z "$_OP" || -z "$_SERVER" ]]
then
	echo
	echo "ERROR: Parameters missing"
	usage
	exit 1
fi

case "$_OP" in
	"get-grid")	get-grid;		shift ;;
	"get-master")	get-master;		shift ;;
	"add")		add-host;		shift ;;
	"ip-update")	update-host-ip;		shift ;;
	"reserve")	reserve-host		shift ;;
	"delete")	delete-host		shift ;;
	"fqdn-update")	update-host-fqdn;	shift ;;
	"search-dns")	search-dns;		shift ;;
	*)
		echo
		echo "*** Unknown operation ***" 
		echo
		echo "Available operations:"
		echo "- add: add new HOST record."
		echo "- delete: delete FQDN."
		echo "- ip-update: update the A record of FQDN."
		echo "- fqdn-update: update the FQDN of an A record."
		echo "- reserve: create a FQDN with the next available IP in subnet."
		echo "- get-grid: get grid members"
		echo "- get-master: get the Grid Master"
		echo "- search-dns: find an FQDN entry"
		echo
		echo "Nick Accad <naccad@gmail.com> 2019-2020"
		exit 1
		;;
esac

