#!/usr/bin/fish

# SANITY CHECKS

if ! is_root 
    print_error "NOT ROOT"
    exit 1
end

# LOGIC START

/etc/autovpn/autovpn.py /etc/autovpn/config.conf $argv