#!/bin/sh
# This script is meant to be POSIX compatible, to work on as many different systems as possible.
# Please try to stick to this. Use a tool like shellcheck to validate changes.
set -eu

# The whole body of the script is wrapped in a function so that a partially
# downloaded script does not get executed by accident. The function is called
# at the end.
main () {
    dune_bin_git_url="https://github.com/ocaml-dune/dune-bin"

    # Reset
    Color_Off='\033[0m' # Text Reset

    # Regular Colors
    Red='\033[0;31m'    # Red
    Green='\033[0;32m'  # Green
    Yellow='\033[0;33m' # Yellow
    White='\033[0;0m'   # White

    # Bold
    Bold_Green='\033[1;32m' # Bold Green
    Bold_White='\033[1m'    # Bold White

    print_error() {
        printf "%berror%b: %s\n" "$Red" "$Color_Off" "$*" >&2
    }

    error() {
        print_error "$@"
        exit 1
    }

    error_download_failed() {
        tar_uri="$1"
        version="$2"
        print_error "Failed to download Dune archive from \"$tar_uri\""
        print_error "Check that $version corresponds to a version of Dune with a binary release."
        print_error "A list of Dune versions with binary releases can be found at: $dune_bin_git_url/releases"
        exit 1
    }

    warn() {
        printf "%bwarn%b: %s\n" "$Yellow" "$Color_Off" "$*" >&2
    }

    info() {
         printf "%b%s %b" "$White" "$*" "$Color_Off"
    }

    info_bold() {
        printf "%b%s %b" "$Bold_White" "$*" "$Color_Off"
    }

    success() {
        printf "%b%s %b" "$Green" "$*" "$Color_Off"
    }

    success_bold() {
        printf "%b%s %b" "$Bold_Green" "$*" "$Color_Off"
    }

    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    ensure_command() {
        command_exists "$1" || error "Failed to find \"$1\". This script needs \"$1\" to be able to install Dune."
    }

    unsubst_home() {
        echo "$1" | sed -e "s#^$HOME#\$HOME#"
    }

    opam_switch_before_dot_local_bin_in_path() {
        # The most conventional place to install dune is ~/.local but if
        # ~/.local/bin is already in the user's PATH variable and the current
        # opam switch appears in PATH before ~/.local/bin then this will cause
        # any dune managed by opam to take precedence over the dune installed
        # by this script, which is likely not what the user intended when they
        # ran this script. This function detects this case and returns 0 iff
        # ~/.local/bin is already in PATH and is behind the current opam
        # switch's bin directory.
        echo "$PATH" |\
            tr ':' '\n' |\
            grep "\(\($HOME\|~\)/\.local/bin\)\|\(\($HOME\|~\)/\.opam\)" |\
            sed 's#.*opam.*#opam#' |\
            sed 's#.*local.*#local#' |\
            paste -sd: - |\
            grep '^\(opam:\)\+\(local\)' > /dev/null
    }

    latest_binary_dune_version() {
        ensure_command "git"
        git ls-remote --tags "$dune_bin_git_url" | cut -f2 | sed 's#^refs/tags/##' | tail -n1
    }

    infer_shell_name() {
        # In most environments the $SHELL variable will be set to shell in the
        # current user's login info. However the case that the $SHELL variable
        # is unset we can still infer the user's shell from the presence of
        # other environment variables. The goal here is to determine the shell
        # from which the user ran the install script, the idea being that
        # that's the shell whose config file they'll (possibly) want the script
        # to update.
        if [ -n "${SHELL+x}" ]; then
            basename "$SHELL"
        else
            if [ -n "${BASH_VERSINFO+x}" ]; then
                echo "bash"
            elif [ -n "${ZSH_VERSION+x}" ]; then
                echo "zsh"
            else
                warn "Unable to identify your shell. Assuming posix sh. Rerun the installer with the '--shell' option to override."
                echo "sh"
            fi
        fi
    }

    exit_message() {
        info_bold "This installer will now exit."
    }

    usage() {
        echo "Usage: install.sh VERSION [options]"
        echo
        echo "Options:"
        echo "--help, -h                Print this help message"
        echo "--install-root PATH       Install Dune to the specified location instead of prompting"
        echo "--update-shell-config     Always the shell config (e.g. .bashrc) if necessary"
        echo "--no-update-shell-config  Never update the shell config (e.g. .bashrc)"
        echo "--shell-config PATH       Use this file as your shell config when updating the shell config"
        echo "--shell SHELL             One of: bash, zsh, fish, sh. Installer will treat this as your shell. Use 'sh' for minimal posix shells such as ash"
    }

    install_root=""
    should_update_shell_config=""
    while [ "$#" -gt "0" ]; do
        arg="$1"
        shift
        case "$arg" in
            -h|--help)
                usage
                exit 0
                ;;
            --install-root)
                if [ "$#" -eq "0" ]; then
                    error "--install-root must be passed an argument"
                fi
                install_root="$1"
                shift
                case "$install_root" in
                    /*)
                        ;;
                    *)
                        error "--install-root must be passed an absolute path (got \"$install_root\")"
                        ;;
                esac
                ;;
            --update-shell-config)
                should_update_shell_config="y"
                ;;
            --no-update-shell-config)
                should_update_shell_config="n"
                ;;
            --shell-config)
                if [ "$#" -eq "0" ]; then
                    error "--shell-config must be passed an argument"
                fi
                shell_config="$1"
                shift
                ;;
            --shell)
                if [ "$#" -eq "0" ]; then
                    error "--shell must be passed an argument"
                fi
                shell_name="$1"
                shift
                case "$shell_name" in
                    bash|zsh|fish|sh)
                        ;;
                    *)
                        error "--shell must be passed one of bash, zsh, fish, sh. Got $shell_name."
                        ;;
                esac
                ;;
            -*)
                print_error "Unknown option: $arg"
                usage
                exit 1
                ;;
            *)
                if [ -z "${version+x}" ]; then
                    version="$arg"
                else
                    error "Expected single anonymous argument (the Dune version) but got multiple: $version, $arg"
                fi
                ;;
        esac
    done

    echo
    info_bold "Welcome to the Dune installer!"
    echo

    if [ -z "${version+x}" ]; then
        echo
        info "No Dune version was specified, so the installer will check the latest binary release of Dune..."
        echo
        version=$(latest_binary_dune_version)
        echo
        info "The latest binary release of Dune was found to be $version."
        echo
    fi

    case $(uname -ms) in
        'Darwin x86_64')
            target=x86_64-apple-darwin
            ;;
        'Darwin arm64')
            target=aarch64-apple-darwin
            ;;
        'Linux x86_64')
            target=x86_64-unknown-linux-musl
            ;;
        *)
            error "The Dune installation script does not currently support $(uname -ms)."
    esac
    tarball="dune-$version-$target.tar.gz"
    tar_uri="$dune_bin_git_url/releases/download/$version/$tarball"
    # The tarball is expected to contain a single directory with this name:
    tarball_dir="dune-$version-$target"

    ensure_command "tar"
    ensure_command "gzip"
    ensure_command "curl"

    echo
    printf "This will guide you through the installation of %bDune %s%b."  "$Bold_White" "$version" "$Color_Off"
    echo
    echo

    if [ -z "$install_root" ]; then
        install_root_local="$HOME/.local"
        install_root_dune="$HOME/.dune"
        if opam_switch_before_dot_local_bin_in_path; then
            warn "Your current opam switch is earlier in your \$PATH than Dune's recommended install location. This installer would normally recommend installing Dune to $install_root_local however in your case this would cause the Dune executable from your current opam switch to take precedent over the Dune installed by this installer. This installer will proceed with an alternative default installation directory $install_root_dune which you are free to override."
            echo
            default_install_root="$install_root_dune"
            install_root_local_message=""
            install_root_dune_message=" (recommended)"
        else
            default_install_root="$install_root_local"
            install_root_local_message=" (recommended)"
            install_root_dune_message=""
        fi
    fi

    while [ -z "$install_root" ]; do
        info "Where would you like to install Dune? (enter index number or custom absolute path)"
        echo
        info "1) $install_root_local$install_root_local_message"
        echo
        info "2) $install_root_dune$install_root_dune_message"
        echo
        info_bold "[$default_install_root] >"
        read -r choice < /dev/tty

        case "$choice" in
            "")
                install_root=$default_install_root
                ;;
            1)
                install_root=$install_root_local
                ;;
            2)
                install_root=$install_root_dune
                ;;
            /*)
                install_root=$choice
                ;;
            *)
                echo
                warn "Unrecognized choice: $choice"
                echo
                ;;
        esac
    done

    echo
    info "Dune $version will now be installed to $install_root"
    echo

    tmp_dir="$(mktemp -d -t dune-install.XXXXXXXX)"
    trap 'rm -rf "$tmp_dir"' EXIT

    # Determine whether we can use --no-same-owner to force tar to extract with user permissions.
    touch "$tmp_dir/tar-detect"
    tar cf "$tmp_dir/tar-detect.tar" -C "$tmp_dir" tar-detect
    if tar -C "$tmp_dir" -xf "$tmp_dir/tar-detect.tar" --no-same-owner; then
        tar_owner="--no-same-owner"
    else
        tar_owner=""
    fi
    tmp_tar="$tmp_dir/$tarball"

    curl --fail --location --progress-bar \
        --proto '=https' --tlsv1.2 \
        --output "$tmp_tar" "$tar_uri" ||
        error_download_failed "$tar_uri" "$version"

    tar -xf "$tmp_tar" -C "$tmp_dir" "$tar_owner" > /dev/null 2>&1 ||
        error "Failed to extract Dune archive content from \"$tmp_tar\""

    mkdir -p "$install_root"
    for d in "$tmp_dir/$tarball_dir"/*; do
        cp -rf "$d" "$install_root"
    done

    echo
    success "Dune successfully installed to $install_root!"
    echo
    echo

    shell_name=${shell_name:-$(infer_shell_name)}
    env_dir="$install_root/share/dune/env"
    case "$shell_name" in
        sh|ash|dash)
            env_file="$env_dir/env.bash" # TODO: change this to env.sh once env.sh is added to the dune binary distro
            shell_config="${shell_config:-$HOME/.profile}"
            ;;
        bash)
            env_file="$env_dir/env.bash"
            shell_config="${shell_config:-$HOME/.bashrc}"
            ;;
        zsh)
            env_file="$env_dir/env.zsh"
            shell_config="${shell_config:-$HOME/.zshrc}"
            ;;
        fish)
            env_file="$env_dir/env.fish"
            shell_config="${shell_config:-$HOME/.config/fish/config.fish}"
            ;;
        *)
            info "The install script does not recognize your shell ($shell_name)."
            echo
            info "It's up to you to ensure $install_root/bin is in your \$PATH variable."
            echo
            exit_message
            echo
            exit 0
            ;;
    esac

    dune_env_call="__dune_env $(unsubst_home "$install_root")"
    shell_config_code() {
        echo "# From Dune installer:"
        echo "source $(unsubst_home "$env_file")"
        echo "$dune_env_call"
    }

    if [ -f "$shell_config" ] && match=$(grep -n "$(echo "$dune_env_call" | sed 's#\$#\\$#')" "$shell_config"); then
        info "It appears your shell config file ($shell_config) is already set up correctly as it contains the line:"
        echo
        info "$match"
        echo
        echo
        info "Just in case it isn't, here are the lines that need run when your shell starts to initialize Dune:"
        echo
        echo
        shell_config_code
        echo
        exit_message
        echo
        exit 0
    fi

    info "To run dune from your terminal, you'll need to add the following lines to your shell config file ($shell_config):"
    echo
    echo
    shell_config_code
    echo

    while [ -z "$should_update_shell_config" ]; do
        info_bold "Would you like these lines to be appended to $shell_config? ([y]/n) >"
        read -r choice < /dev/tty
        case "$choice" in
            "")
                should_update_shell_config="y"
                ;;
            y|Y)
                should_update_shell_config="y"
                ;;
            n|N)
                should_update_shell_config="n"
                ;;
            *)
                warn "Please enter y or n."
                echo
                ;;
        esac
    done

    case "$should_update_shell_config" in
        y)
            shell_config_code >> "$shell_config"
            echo
            success "Added Dune setup commands to $shell_config!"
            echo
            info "Restart your terminal for the changes to take effect."
            echo
            ;;
        *)
        ;;
    esac

    exit_message
    echo
}
main "$@"
