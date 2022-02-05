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

print_exec mkdir /etc/router

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

set interfaces (ip link list | grep -Eo "^[0-9]*: [A-z0-9\-]*" | grep -Po "(?![0-9]*:)(?! ).*")
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

    # turning it into an array
    set interfaces (string split ' ' $interfaces)

    print_green "Valid interfaces: "$interfaces

    if test (count $interfaces) -eq 1
        echo "Only one valid interface found, selecting it as WAN_INTERFACE"
        set -Ux WAN_INTERFACE $interfaces[1]
    else
        # turning it back into a single argument. I know it's a mess, DON'T JUDGE ME! I've gotta have it done in like 3h...
        set interfaces (echo $interfaces) 
        set interfacen (dialog --no-cancel --menu "Select the internet-facing interface:" 18 70 15 \
            (echo $interfaces | sed "s/ /\n/g" | nl --number-separator=(echo -e " ") | sed "s/[ ]/\n/g" | grep -v "^\$")\
            3>&1 1>&2 2>&3 3>&-)
        # aaaaand back into an array
        set interfaces (string split ' ' $interfaces)
        set interface $interfaces[$interfacen]
        if test ! -n "$interface"
            print_error "INVALID INTERFACE SELECTED"
            exit 1
        end
        set -Ux WAN_INTERFACE $interface
    end
end

print_green "WAN_INTERFACE is: $WAN_INTERFACE"

echo $WAN_INTERFACE > "/etc/router/WAN_INTERFACE"

# setup forwarding

echo 1 > /proc/sys/net/ipv4/ip_forward


# remove netplans

for it in (find /etc/netplan/ -type f)
    print_exec chattr -i $it
    print_exec rm $it
end

# setup neplan

set NETPLAN_FILE "/etc/netplan/50-cloud-init.yaml"

print_exec chattr -i $NETPLAN_FILE
print_exec rm $NETPLAN_FILE

print_exec touch $NETPLAN_FILE

echo "network:" >> $NETPLAN_FILE
echo "  version: 2" >> $NETPLAN_FILE
echo "  ethernets:" >> $NETPLAN_FILE
echo "    $WAN_INTERFACE:" >> $NETPLAN_FILE
echo "      dhcp4: true" >> $NETPLAN_FILE
echo "      dhcp6: no" >> $NETPLAN_FILE
echo "      optional: true" >> $NETPLAN_FILE
echo "    $LAN_INTERFACE:" >> $NETPLAN_FILE
echo "      dhcp4: no" >> $NETPLAN_FILE
echo "      dhcp6: no" >> $NETPLAN_FILE
echo "      addresses: [$LAN_ROOT_IP_MASK]" >> $NETPLAN_FILE

print_exec cat $NETPLAN_FILE

print_exec chattr +i $NETPLAN_FILE

if ! print_exec netplan apply
    print_error "NETPLAN ERROR! Aborting..." 
    exit 1
end

# disable ipv6 on the WAN interface

sudo sysctl -w net.ipv6.conf.$WAN_INTERFACE.disable_ipv6=1


# setup the service and enable it

print_exec cp ./router.service /etc/systemd/system/router.service
print_exec systemctl daemon-reload
print_exec systemctl stop router
print_exec systemctl enable router

# setup the firewall

ufw default allow outgoing 
ufw default allow forward
ufw allow from $LAN_NET_IP_MASK

ufw enable