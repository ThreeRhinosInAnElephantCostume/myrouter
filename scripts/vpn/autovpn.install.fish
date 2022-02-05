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

if test ! -e "./autovpn.fish"
    print_error "COULD NOT FIND ./autovpn.fish. Corrupted install?"
    exit 1
end

if test ! -e "./autovpn.py"
    print_error "COULD NOT FIND ./autovpn.py. Corrupted install?"
    exit 1
end

if test ! -n $LAN_INTERFACE
    print_error "LAN_INTERFACE WAS NOT DEFINED!"
    exit 1
end

# LOGIC START

print_exec cp ./autovpn.fish /usr/bin/auto_vpn
print_exec chmod 777 /usr/bin/auto_vpn

print_exec mkdir /etc/autovpn
print_exec chown ubuntu:ubuntu /etc/autovpn
print_exec cp ./autovpn.py /etc/autovpn/autovpn.py
print_exec chmod 777 /etc/autovpn/autovpn.py
print_exec touch /etc/autovpn/state.conf
print_exec touch /etc/autovpn/permastate.conf

set DEFAULT_VPN_IP "0.0.0.0"

if test -e "/etc/autovpn/config.conf"
    set DEFAULT_VPN_IP (cat /etc/autovpn/config.conf | grep -Eo "devip = \"([0-9\.].*)*\"" | grep -Eo "[0-9\.]*")
end

print_exec mkdir /etc/autovpn/servers
cat config.default.conf | sed "s/LAN_INTERFACE/$LAN_INTERFACE/g" | sed "s/DEFAULT_VPN_IP/$DEFAULT_VPN_IP/g"  > ./config.tmp.conf
print_exec cp ./config.tmp.conf /etc/autovpn/config.conf
print_exec rm ./config.tmp.conf

print_exec chown ubuntu:ubuntu /etc/autovpn/config.conf
print_exec chown ubuntu:ubuntu /etc/autovpn/state.conf
print_exec chown ubuntu:ubuntu /etc/autovpn/permastate.conf
print_exec chown ubuntu:ubuntu /etc/autovpn/servers