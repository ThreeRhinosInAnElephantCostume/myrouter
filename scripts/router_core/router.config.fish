#!/usr/bin/fish

set -Ux LAN_INTERFACE eth0
if test -e /etc/router/WAN_INTERFACE
    set -Ux WAN_INTERFACE (cat /etc/router/WAN_INTERFACE)
end
#set -Ux WAN_INTERFACE eth1
set -Ux WIFI_INTERFACE wlan0

set -Ux LAN_ROOT_IP_MASK 192.168.0.1/24
set -Ux LAN_ROOT_IP 192.168.0.1

set -Ux LAN_NET_IP_MASK 192.168.0.0/24
set -Ux LAN_NET_IP 192.168.0.0
set -Ux LAN_NET_MASK 24
set -Ux LAN_NET_MASK_NUMERIC 255.255.255.0

exit 0