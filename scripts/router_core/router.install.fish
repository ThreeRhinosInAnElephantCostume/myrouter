#!/usr/bin/fish

if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

set -Ux WAN_INTERFACE ""

./router.config.fish

if test ! -n "$WAN_INTERFACE"
    set interfaces (ip link list | grep -Eo "^[0-9]*: [A-z0-9]*" | grep -Po "(?![0-9]*:)(?! ).*")
    set forbidden lo $LAN_INTERFACE $WIFI_INTERFACE
    for int in $forbidden
        set exp "s/[ ]*"$int"[ ]*//g"
        set interfaces (echo $interfaces | sed $exp)
    end

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



