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

set -Ux RED '\033[0;31m'
set -Ux YELLOW '\033[0;33m'
set -Ux GREEN '\033[0;32m'
set -Ux NULL_COLOR '\033[0m'

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