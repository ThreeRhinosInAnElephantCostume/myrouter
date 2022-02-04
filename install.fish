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

# LOGIC START

echo "Copying utilities"

print_exec $BASEDIR
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

echo "Installing fancontrol"

print_exec cd $BASEDIR
print_exec cd "scripts/fancontrol"

if ! ./fancontrol.install.fish
    print_error "fancontrol.install.fish failed, aborting installation"
    exit 1
end

print_exec cd $BASEDIR 
print_success "INSTALLATION SCUCCESSFUL!"

exit 0