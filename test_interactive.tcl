#!/usr/bin/env expect
# Expect script for interactively running the installation script, exercising
# input validation for interactive prompts and testing that the modifications
# to the shell config are what we expect.

set timeout 10

# Dune will be installed to this temporary directory.
set tmp [exec mktemp -d]

# Run the install script, pointing it to a temporary bashrc, and forcing it to
# assume bash is the current shell for portability.
spawn ./install.sh 3.19.1 --shell-config $tmp/bashrc --shell bash

# The prompt for where dune will be installed. Try entering an invalid choice
# to exercise input validation:
expect "> "
send "foo\r"
expect {
    timeout { exit 1 }
    "Unrecognized choice: foo"
}

# Now we're back at the prompt for where dune will be installed. This time
# enter the path to the temporary directory:
expect "> "
send "$tmp\r"
expect "Dune successfully installed to $tmp!"

# Now we're at the prompt for whether or not to update the shell config. Try
# entering something invalid first to exercise input validation:
expect "Would you like these lines to be appended to $tmp/bashrc?"
send "foo\r"
expect {
    timeout { exit 1 }
    "Please enter y or n."
}

# Now we're back at the prompt for whether or not to update the shell config.
# This time enter "y".
expect "Would you like these lines to be appended to $tmp/bashrc?"
send "y\r"

expect "This installer will now exit."

# Now test that the generated bashrc contains what we expect:
spawn cat $tmp/bashrc
expect {
    eof {
        "Unexpected contents of shell config!"
        exit 1
    }
    "# From dune installer:\r\nsource $tmp/share/dune/env/env.bash\r\n__dune_env $tmp"
}
