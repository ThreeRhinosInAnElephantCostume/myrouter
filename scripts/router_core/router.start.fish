#!/usr/bin/fish


# SANITY CHECKS
if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

if ! router_config
    print_error "ROUTER CONFIG RETURNED AN ERROR! Aborting..."
    exit 1
end

if test ! -n "$WAN_INTERFACE"
    print_error "WAN_INTERFACE IS UNDEFINED!"
    exit 1
end

if test ! -n "$LAN_INTERFACE"
    print_error "LAN_INTERFACE IS UNDEFINED!"
    exit 1
end

# LOGIC START

echo "restarting interfaces..."

print_exec ip link set $WAN_INTERFACE down
print_exec ip link set $WAN_INTERFACE up
print_exec ip link set $LAN_INTERFACE down
print_exec ip link set $LAN_INTERFACE up

echo "allowing one second for interfaces to get their shit together"

sleep 1

#set up forwarding
echo "setting up forwarding"
print_exec iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE
print_exec iptables -A INPUT -i $WAN_INTERFACE -j ACCEPT
print_exec iptables -A INPUT -i $LAN_INTERFACE -m state --state ESTABLISHED,RELATED -j ACCEPT
print_exec iptables -A OUTPUT -j ACCEPT

echo "setting up packet multithreading"
#This may or may not increase performance
#Remove if it causes any issues
print_exec echo 2 > /sys/class/net/$LAN_INTERFACE/queues/rx-0/rps_cpus
print_exec echo 1 > /sys/class/net/$WAN_INTERFACE/queues/rx-0/rps_cpus

echo "ensure that ipv6 is disabled" # also made changes to /etc/sysctl.conf and /etc/sysctl.d/40-ipv6.con
print_exec ip6tables -P INPUT DROP

#echo "starting dnsvpn"
#start vpn-ing dns traffic
#sudo /home/ubuntu/startdnsvpn

echo "waiting one second for dnsvpn to start"
#ensure no conflict with the vpn
sleep 1

echo "restoring autovpn"
print_exec auto_vpn start
echo "waiting for vpns to start"

sleep 1
echo "starting dnsvpn"
print_exec router_start_dnsvpn
echo "done"


# setup resolv-conf

echo "ensuring correct /etc/resolv.conf"

print_exec chattr -i /etc/resolv.conf
print_exec rm /etc/resolv.conf
print_exec touch /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf
print_exec chattr +i /etc/resolv.conf

