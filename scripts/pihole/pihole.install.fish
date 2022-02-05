#!/usr/bin/fish

if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

set -e

if test -e "/usr/local/bin/pihole"
    print_success "Pihole already installed, exiting..."
    exit 0
end

if ! print_exec git clone --depth 1 https://github.com/pi-hole/pi-hole.git Pi-hole
    print_error "Error downloading pihole, check your internet connection!"
    exit 1
end
print_exec cd "Pi-hole/automated install/"
if ! print_exec bash basic-install.sh
    print_error "The install script threw an error!"
    exit 1
end

exit 0