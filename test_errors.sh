#!/bin/sh
# Tests error cases for the install script.
# These tests should have no side effects.

main() {
    if [ "$#" -ne "1" ]; then
        echo "Expected 1 argument (the path to the install script). Got $#."
        exit 1
    fi
    install_script="$1"
    install() {
        $install_script "$@"
    }

    test_title() {
        echo
        echo
        echo "$@"
    }

    test_title "Test behaviour when no version is specified:"
    install

    test_title "Test that only a single anonymous argument is allowed:"
    install foo bar

    test_title "Test that unknown command-line arguments are detected:"
    install --foo

    test_title "Test that omitting the argument to --install-root is an error:"
    install 3.19.1 --install-root

    test_title "Test that passing anything other than an absolute path to --install-root is an error:"
    install 3.19.1 --install-root foo

    test_title "Test that --shell-config requires an argument:"
    install 3.19.1 --shell-config

    test_title "Test that --shell requires an argument:"
    install 3.19.1 --shell

    test_title "Test that --shell validates its argument:"
    install 3.19.1 --shell foo
}

main "$@" 2>&1
