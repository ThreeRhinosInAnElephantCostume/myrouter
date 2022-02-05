#!/usr/bin/fish

if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

print_exec git clone --depth 1 https://github.com/pi-hole/pi-hole.git Pi-hole
print_exec cd "Pi-hole/automated install/"
if ! print_exec bash basic-install.sh
    print_error "The install script threw an error!"
    exit 1
end

exit 0