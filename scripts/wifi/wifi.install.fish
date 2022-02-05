#!/usr/bin/fish

# SANITY CHECKS


if ! router_config
    print_error "ROUTER CONFIG RETURNED AN ERROR! Aborting..."
    exit 1
end

if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

# LOGIC START

if test -e "./SSID.txt"
    set SSID (cat "./SSID.txt")
    if ! echo "$SSID" | grep -q -E "^[A-z0-9\-]*\$"
        print_error "Invalid SSID! ($SSID)"
        exit 1
    end
else
    echo "Input network SSID:"
    set LOOP 0
    while $LOOP
        set SSID (read)
        if echo "$SSID" | grep -q -E "^[A-z0-9\-]*\$"
            set LOOP 1
        end
        print_error "Invalid SSID! Try again."
    end
end

if test -e "./PASSWORD.txt"
    set PASSWORD (cat "./PASSWORD.txt")
else
    echo "Input network password:"
    set PASSWORD (read)
end

echo "Setting up hostapd with:"
echo "SSID=$SSID"
echo "PASSWORD=$PASSWORD"

print_exec systemctl unmask hostapd
print_exec systemctl enable hostapd

print_exec systemctl enable systemd-networkd

cat ./hostapd.default.conf | sed "s/SSID/$SSID/g" | sed "s/PASSWORD/$PASSWORD/g" | sed "s/WIFI_INTERFACE/$WIFI_INTERFACE/g"  > /etc/hostapd/hostapd.conf

print_warning "MANUAL DHCP CONFIG REQUIRED!"

rfkill unblock wlan