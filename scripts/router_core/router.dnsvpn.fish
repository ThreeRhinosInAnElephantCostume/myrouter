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

#this should probably be redone in a configurable and extendable way, but I can't be asked rn

#set up the killswitch
print_exec ip rule add pref 777 to 1.1.1.1 lookup 13
print_exec ip route add table 13 blackhole default

#ip=$(cat ./mullvad/mullvad-ch9.conf | grep -Eo "[^ ]{7,17}/32")

#set up the vpn
#sudo ip link add dnsvpn type wireguard
#sudo ip addr add dev dnsvpn $ip #10.67.156.181/32
#sudo wg setconf dnsvpn /home/ubuntu/autovpn/servers/de/mullvad-de21.conf
#sudo ip link set up dev dnsvpn

print_exec auto_vpn add ch --name="dnsvpn" --noip --unique

#redirect all dns ips to the vpn device

print_exec ip rule add pref 666 to 1.1.1.1 lookup 12
print_exec ip route add table 12 default dev dnsvpn
