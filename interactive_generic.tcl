#!/usr/bin/env expect
# Expect script for interactively running the installation script. This script
# takes arguments which it passes to the interactive prompts of the install
# script.

set timeout 10

set install_script [lindex $argv 0]
set version [lindex $argv 1]
set install_root [lindex $argv 2]

# Create a temporary directory to store the shell config
set tmp [exec mktemp -d]

spawn "$install_script" "$version" --shell bash --shell-config "$tmp/bashrc"

expect "> "
send "$install_root\r"
expect "Dune successfully installed"

expect "Would you like these lines to be appended to $tmp/bashrc?"
send "y\r"

expect "This installer will now exit."

