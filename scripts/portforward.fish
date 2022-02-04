#!/bin/fish
set DEV $argv[1]
set IP $argv[2]
set PORT $argv[3]
set TARGET_PORT $argv[4]
set REMOVE $argv[5]

if [ "$TARGET_PORT" = "--remove" ]
    set REMOVE $TARGET_PORT
    set TARGET_PORT ""
end

function print_help
    printf "\n"
    echo "forward: forward a port on device for a host"
    echo "forward [DEVICE] [IP] [PORT] [opt TARGET_PORT] [opt --remove]"
    printf "\n"
end

function forward_protocol
    print_exec sudo iptables $ACT PREROUTING -t nat -i $DEV -p $argv --dport $PORT -j DNAT --to $IP_PORT
    print_exec sudo iptables $ACT FORWARD -p $argv -d $IP --dport $TARGET_PORT -j ACCEPT
end

function print_exec
    echo ">>> $argv"
    $argv
end

if [ ! "$PORT"  ]
    echo "ERROR: Not enough arguments"
    print_help
    exit 1
end


if [ ! "$TARGET_PORT" ]
    echo "No target specified, $PORT assumed"
    set TARGET_PORT $PORT
end 

set IP_PORT "$IP:$TARGET_PORT"

echo "ensuring root permissions:"
sudo echo "access granted"


set ACT "-A"

if [ "$REMOVE" = "--remove" ]
    echo "removing $IP_PORT on device $DEV"
    set ACT "-D"
else
    echo "forwarding $PORT on device $DEV to $IP_PORT:"
end

forward_protocol tcp
forward_protocol udp