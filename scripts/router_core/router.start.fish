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

# LOGIC START

echo "setting up forwarding"
#set up forwarding
print_exec iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
print_exec iptables -A INPUT -i eth0 -j ACCEPT
print_exec iptables -A INPUT -i eth1 -m state --state ESTABLISHED,RELATED -j ACCEPT
print_exec iptables -A OUTPUT -j ACCEPT

echo "setting up packet multithreading"
#This may or may not increase performance
#Remove if it causes any issues
print_exec echo 2 > /sys/class/net/eth1/queues/rx-0/rps_cpus
print_exec echo 1 > /sys/class/net/eth0/queues/rx-0/rps_cpus

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



