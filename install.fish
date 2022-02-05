#!/usr/bin/fish

if test ! -e ./commands.fish
    echo "COMMAND FILE NOT FOUND! Are you sure you've started the script from the correct directory?"
    exit 1
end

if ! ./commands.fish 
    echo "COULD NOT LOAD COMMANDS!"
    exit 1
end


# VARIABLES

set BASEDIR (pwd)

# SANITY CHECKS

if ! is_root 
    print_error "NOT ROOT!"
    exit 1
end

print_success "RUNNING AS ROOT"

print_exec cp ./commands.fish /usr/bin/router_commands
print_exec chmod 777 /usr/bin/router_commands

# INSTALLING DEPENDENCIES

print_exec cd $BASEDIR

echo "Installing dependencies"
print_exec apt update
if ! print_exec apt install (string split ' ' (cat ./dependencies.txt)) -y
    print_error "apt failed to install some or all dependencies"
    exit 1
end

print_success "Successfully installed all dependencies"

# APT FULL-UPGRADE

echo "Performing a package upgrade"

print_exec apt update
print_exec apt full-upgrade -y
print_exec apt autoremove -y

print_success "Done upgrading"

# COPY UTILITIES

echo "Copying utilities"

print_exec cd $BASEDIR
print_exec cd "scripts/utils"


for script in (find . -type f)
    set scriptinstallpath "/usr/bin/"(basename $script ".fish")
    set scriptinstallpath "/usr/bin/"(basename $scriptinstallpath ".sh")
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
print_exec cd scripts/pihole

if ! print_exec ./pihole.install.fish
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
print_success "INSTALLATION SUCCESSFUL!"

print_yellow "NOTE: Manual PIHOLE configuration required."

print_warning "-----> RESTART REQUIRED! <-----"

exit 0