#!/usr/bin/fish

# returns  0 if true, 1 if false
function is_root 
    return (test (id -u) -eq 0)
end

# prints its arguments, then executes them as a command
function print_exec
    echo ">>> $argv"
    $argv
end

set RED '\033[0;31m'
set YELLOW '\033[0;33m'
set GREEN '\033[0;32m'
set NULL_COLOR '\033[0m'

function print_colored
    echo -e "$argv[1]""$argv[2..-1]""$NULL_COLOR"
end

function print_red
    print_colored $RED "$argv"
end
function print_yellow
    print_colored $YELLOW"$argv"
end
function print_green
    print_colored $GREEN "$argv"
end

function print_error
    print_red "ERROR:" "$argv"
end
function print_warning
    print_yellow "WARNING:" "$argv"
end
function print_success
    print_green "SUCCESS:" "$argv"
end

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

if test ! -e "/etc/fanctonrol/fancontrol.config.json"
    print_exec cp ./fancontrol.default.json /etc/fancontrol/fancontrol.config.json
end

print_exec chmod 777 ./fancontrol.py
print_exec cp ./fancontrol.py /usr/bin/fancontrol
print_exec chmod 777 /usr/bin/fancontrol

print_exec cp ./fancontrol.service /etc/systemd/system/fancontrol.service
print_exec sudo systemctl daemon-reload
print_exec sudo systemctl enable fancontrol
print_exec sudo systemctl start fancontrol

exit 0
