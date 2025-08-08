#!/usr/bin/env expect
# Expect script for interactively running the installation script. This script
# takes arguments which it passes to the interactive prompts of the install
# script.

set timeout 10

set install_script [lindex $argv 0]
set version [lindex $argv 1]
set install_root [lindex $argv 2]
set shell_config [lindex $argv 3]

# Create a temporary directory to store the shell config
set tmp [exec mktemp -d]

spawn "$install_script" "$version"

expect "> "
send "$install_root\r"
expect "Dune successfully installed"

expect "Enter the absolute path of your shell config file or leave blank for default"
expect "> "
send "$shell_config\r"

expect "Would you like these lines to be appended to"
send "y\r"

expect "This installer will now exit."
