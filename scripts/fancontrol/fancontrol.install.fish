#!/usr/bin/fish

# Sanity checks

if ! is_root
    print_error "NOT ROOT"
    exit 1
end

if test ! -e "./fancontrol.default.json"
    print_error "COULD NOT FIND DEFAULT CONFIG! Corrupted install?"
    exit 1 
end

if test ! -e "./fancontrol.py"
    print_error "COULD NOT FIND SCRIPT! Corrupted install?"
    exit 1
end

if test ! -e "./fancontrol.service"
    print_error "COULD NOT FIND SERVICE FILE! Corrupted install?"
    exit 1
end

# Logic start

if test ! -d "/etc/fancontrol"
    print_exec mkdir /etc/fancontrol
end 

set override 0

print_exec cp ./fancontrol.default.json /etc/fancontrol/fancontrol.config.json

print_exec chmod 777 ./fancontrol.py
print_exec cp ./fancontrol.py /usr/bin/fancontrol
print_exec chmod 777 /usr/bin/fancontrol

print_exec cp ./fancontrol.service /etc/systemd/system/fancontrol.service
print_exec systemctl daemon-reload
print_exec systemctl stop fancontrol
print_exec systemctl enable fancontrol
print_exec systemctl restart fancontrol

exit 0
