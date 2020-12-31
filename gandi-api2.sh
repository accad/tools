#!/bin/sh
#
# Detects the IP4 and IP6 of the local machine and update Gandi LiveDNS
# Very very basic, not much error checking
# Using as much of the original SH as possible, the only thing needed is "curl"
# I used this on a base install of NetBSD 9.1 with only curl added
#
# Nick Accad <naccad@gmail.com>
# 2020
# 
set +x
#
# You can either put the configuration in ~/.gandi.conf or put them here.
# Here are the variables
#
# _APIKEY=<APIKEY> you get this from Gandi.net https://account.gandi.net/en/users/<USERNAME>/security
# _DOMAIN=<The domain.tld we are working with>
# _HOST=<The host record>
# _CURL_G=<Path to curl>
# _CURL_P=<same as above, I separate the "read" from "put/get" for debugging>
#

if [ -r "$PWD/.gandi.conf" ]; then . $PWD/.gandi.conf; fi

ip4=$($_CURL_G -s4 api64.ipify.org)
ip6=$($_CURL_G -s6 api64.ipify.org)
ip4c=$(host -t A $_HOST.$_DOMAIN | awk '{ print $NF}')
ip6c=$(host -t AAAA $_HOST.$_DOMAIN | awk '{ print $NF}')

d4="Y"
d6="Y"

if [ "$ip4" = "$ip4c" ]; then d4="N"; fi
if [ "$ip6" = "$ip6c" ]; then d6="N"; fi

echo -e "\nRecord:  $_HOST.$_DOMAIN"
echo -e "IPv4[$d4]: [$ip4] [$ip4c]"
echo -e "IPv6[$d6]: [$ip6] [$ip6c]"

generate-json-body() {
cat <<EOF
{ "rrset_name": "$_HOST", "rrset_type": "$2", "rrset_ttl": $3, "rrset_values": [ "$4" ] }
EOF
}

update-gandi-dns() {
  _BODY=$(generate-json-body $_HOST $1 $2 $3)
  $_CURL_P -H "Content-Type: application/json" -H "Authorization: Apikey $_APIKEY" -X PUT -d "$_BODY" \
  https://api.gandi.net/v5/livedns/domains/$_DOMAIN/records/$_HOST/$1
}

if [ $d4 = "Y" ]; then update-gandi-dns "A" "1800" $ip4; fi
if [ $d6 = "Y" ]; then update-gandi-dns "AAAA" "1800" $ip6; fi

echo
