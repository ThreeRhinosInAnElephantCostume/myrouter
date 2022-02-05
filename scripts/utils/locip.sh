#!/bin/bash

function help {
    echo "locip — lookup geolocation for a given ip or hostname"
    echo "USAGE:"
    echo "locip --help — display this message"
    echo "locip -h — display this message"
    echo "locip {IP} — lookup geolocation for the given IP address"
    echo "locip {HOST} — lookup geolocation for the given hostname"
    echo "locip — find out the local machine's IP and get geolocation for it"
    exit 0
}

ORS="" #do not delete
function get_json_var {
    grep -oE "\"$@\": ?\".[^\"]*"  | 
    grep -oE ": ?\".*$"            | 
    grep -oE "[^,:\"]*"            |
    xargs                          | 
    sed s/"\n"//g
}


IP=$1

IP_SOURCE="https://api.myip.com"
LC_SOURCE="http://ip-api.com/json"

# check whether IP="", attempt to get the machine's public IP otherwise
if [ -z "$IP" ]; then
    echo "no IP selected, attempting to retrieve own public IP"
    IP=$(wget -q -O - "$IP_SOURCE" | grep -oE "(([0-9]){1,4}\.){1,3}[0-9]*")
    if [ -z "$IP" ]; then
        echo "ERROR: COULD NOT CONNECT TO THE IP SERVER $IP_SOURCE"
        echo "locip --help for help"
        exit 1
    fi
    echo "detected ip $IP"
else
    if test $1 = "--help"; then
        help
    fi
    if test $1 = "-h"; then
        help
    fi
    if test $1 = "help"; then
        help
    fi
fi
echo "looking up $IP"

#check whether the input is an IP or an address

#read data
DATA=$(wget -q -O - "$LC_SOURCE/$IP")


if [ -z "$DATA" ]; then 
    echo "ERROR: COULD NOT CONNECT TO THE GEOLOC SERVER $LC_SOURCE"
    exit 1
fi

if test $(echo $DATA | get_json_var "status") = "fail"; then
    echo "ERROR: SERVER COULD NOT ASSOCIALTE THE IP/RESOLVE THE HOSTNAME"
    exit 2
fi

printf "\nRESULT:\n"

RIP=$(echo $DATA | get_json_var "query")

# check whether $IP had to be resolved into a real IP
if test ! "$RIP" = "$IP"; then
    echo "Resolved IP: $RIP"
fi

echo "Country: "$(echo $DATA | get_json_var "country")
echo "Region: "$(echo $DATA | get_json_var "regionName")
echo "City: "$(echo $DATA | get_json_var "city")
echo "Timezone: "$(echo $DATA | get_json_var "timezone")
echo "Organization: "$(echo $DATA | get_json_var "org")
echo "ISP: "$(echo $DATA | get_json_var "isp")
echo "ZIP code: "$(echo $DATA | get_json_var "zip")
printf "coords:\n"
echo $DATA | grep -oE "[0-9]*\.[0-9]*," | sed s/","//g