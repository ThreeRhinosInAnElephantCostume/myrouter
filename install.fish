#!/usr/bin/fish

# GLOBAL FUNCTIONS

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

funcsave is_root

funcsave print_exec

funcsave print_colored
funcsave print_red
funcsave print_yellow
funcsave print_green

funcsave print_error
funcsave print_warning
funcsave print_success

# VARIABLES

set BASEDIR (pwd)

# SANITY CHECKS

if ! is_root 
    print_error "NOT ROOT!"
    exit 1
end

# INSTALLING DEPENDENCIES

print_exec cd $BASEDIR

echo "Installing dependencies"
print_exec apt update
if ! print_exec apt install (string split ' ' (cat ./dependencies.txt)) -y
    print_error "apt failed to install some or all dependencies"
    exit 1
end
echo "Successfully installed all dependencies"

# APT FULL-UPGRADE

echo "Performing a package upgrade"

print_exec apt update
print_exec apt full-upgrade -y
print_exec apt autoremove -y

echo "Done upgrading"

# COPY UTILITIES

echo "Copying utilities"

print_exec cd $BASEDIR
print_exec cd "scripts/utils"


for script in (find . -type f)
    set scriptinstallpath "/usr/bin/"(basename $script ".fish")
    if ! print_exec cp $script $scriptinstallpath
        print_error "Error copying $script"
        exit 1
    end
    print_exec chmod 777 $scriptinstallpath
end

print_success "Done copying utilities"

# INSTALL FANCONTROL

echo "Installing fancontrol"

print_exec cd $BASEDIR
print_exec cd "scripts/fancontrol"

if ! ./fancontrol.install.fish
    print_error "fancontrol.install.fish failed, aborting installation"
    exit 1
end

print_success "Done installing fancontrol"

# INSTALL ROUTER_CORE

echo "Installing router_core"

print_exec cd $BASEDIR
print_exec cd scripts/router_core

if ! print_exec ./router.install.fish
    print_error "Error installing router_core, aborting..."
    exit 1 
end

print_success "Done installing router_core"

# 

echo "Installing pihole"

print_exec cd $BASEDIR
print_exec scripts/pihole

if ! print_exe ./pihole.install.fish
    print_error "Error installing pihole, aborting..."
    exit 1
end

print_success "Successfully installed pihole"
print_warning "Check the webserver for further configuration!"

# INSTALL AUTO_VPN

echo "Installing auto_vpn"

print_exec cd $BASEDIR
print_exec cd scripts/vpn

if ! print_exec ./autovpn.install.fish
    print_error "Error installing auto_vpn, aborting..."
    exit 1 
end

print_success "Done installing auto_vpn"

# SUCCESS

print_exec cd $BASEDIR 
print_success "INSTALLATION SCUCCESSFUL!"

print_yellow "NOTE: Manual PIHOLE configuration required."

print_warning "-----> RESTART REQUIRED! <-----"

exit 0