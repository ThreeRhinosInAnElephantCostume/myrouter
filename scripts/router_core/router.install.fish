#!/usr/bin/fish



# SANITY CHECKS
if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

if test ! -e "./router.config.fish"
    print_error "CONFIG NOT FOUND! Corrupted install?"
    exit 1
end

if test ! -e "./router.start.fish"
    print_error "STARTUP SCRIPT NOT FOUND! Corrupted install?"
    exit 1
end


if test ! -e "./router.dnsvpn.fish"
    print_error "DNSVPN SCRIPT NOT FOUND! Corrupted install?"
    exit 1
end

# LOGIC START

print_exec cp ./router.config.fish /usr/bin/router_config
print_exec chmod 777 /usr/bin/router_config

print_exec cp ./router.start.fish /usr/bin/router_start
print_exec chmod 777 /usr/bin/router_start

print_exec cp ./router.dnsvpn.fish /usr/bin/router_start_dnsvpn
print_exec chmod 777 /usr/bin/router_start_dnsvpn

if ! router_config
    print_error "ROUTER CONFIG RETURNED AN ERROR! Aborting..."
    exit 1
end

set interfaces (ip link list | grep -Eo "^[0-9]*: [A-z0-9]*" | grep -Po "(?![0-9]*:)(?! ).*")
set forbidden lo $LAN_INTERFACE $WIFI_INTERFACE
for int in $forbidden
    set exp "s/[ ]*"$int"[ ]*//g"
    set interfaces (echo $interfaces | sed $exp)
end

set -Ux WAN_INTERFACE ""

if test ! -n "$WAN_INTERFACE"

    if test ! -n "$interfaces"
        print_error "NO VALID WAN INTERFACES FOUND!"
        exit 1
    end

    print_green "Valid interfaces: "$interfaces

    if test (count $interfaces) -eq 1
        echo "Only one valid interface found, selecting it as WAN_INTERFACE"
        set -Ux WAN_INTERFACE $interfaces[1]
    else
        set interfacen (dialog --no-cancell --menu "Select the internet-facing interface:" 18 70 15 \
            (echo $interfaces | sed "s/ /\n/g" | nl --number-separator=(echo -e " ") | sed "s/[ ]/\n/g" | grep -v "^\$")\
            3>&1 1>&2 2>&3 3>&-)
        set interface $interfaces[$interfacen]
        if test ! -n "$interface"
            print_error "INVALID INTERFACE SELECTED"
            exit 1
        end
        set -Ux WAN_INTERFACE $interface
    end
end

print_green "WAN_INTERFACE is: $WAN_INTERFACE"

# setup forwarding

print_exec echo 1 > /proc/sys/net/ipv4/ip_forward


# remove netplans

for it in (find /run/systemd/network -type f)
    print_exec rm it
end

# add new netplans

set LAN_FILE "/run/systemd/network/10-netplan-"$LAN_INTERFACE".network"
set WAN_FILE "/run/systemd/network/10-netplan-"$WAN_INTERFACE".network"

# LAN

print_exec touch $WAN_FILE

echo "[Match]" >> $WAN_FILE
echo "Name=$WAN_INTERFACE" >> $WAN_FILE

echo "[Network]" >> $WAN_FILE
echo "DHCP=ipv4" >> $WAN_FILE
echo "LinkLocalAddressing=ipv6" >> $WAN_FILE

echo "[DHCP]" >> $WAN_FILE
echo "RouteMetric=100" >> $WAN_FILE
echo "UseMTU=true" >> $WAN_FILE

print_exec cat $WAN_FILE

# WAN

print_exec touch $LAN_FILE

echo "[Match]" >> $LAN_FILE
echo "Name=$LAN_INTERFACE" >> $LAN_FILE

echo "[Network]" >> $LAN_FILE
echo "LinkLocalAddressing=ipv6" >> $LAN_FILE
echo "Address=$LAN_ROOT_IP_MASK" >> $LAN_FILE

print_exec cat $LAN_FILE

# setup resolv-conf

print_exec chattr -i /etc/resolv.conf
print_exec echo "nameserver 127.0.0.1" > /etc/resolv.conf
print_exec chattr +i /etc/resolv.conf

# setup the service and enable it

print_exec cp ./router.service /etc/systemd/system/router.service
print_exec systemctl daemon-reload
print_exec systemctl stop router
print_exec systemctl enable router