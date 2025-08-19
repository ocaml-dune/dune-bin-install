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

    code() {
        printf "%s\n" "$1"
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

    latest_stable_binary_dune_version() {
        ensure_command "git"
        git_url="$1"
        # matches stable version numbers like "1.2.3"
        stable_version_filter='^[0-9]\+\.[0-9]\+\.[0-9]\+$'
        git ls-remote --tags "$git_url" | cut -f2 | sed 's#^refs/tags/##' | grep "$stable_version_filter" | sort -V | tail -n1
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
        echo "Usage: install.sh [VERSION] [options]"
        echo
        echo "Install a given version of the Dune binary distribution, or the latest stable version if VERSION is not specified."
        echo "Existing versions are listed at: $dune_bin_git_url/releases"
        echo "To install an unstable version (such as an alpha version) the version number must be specified explicitly."
        echo
        echo "Options:"
        echo "--help, -h                Print this help message"
        echo "--install-root PATH       Install Dune to the specified location instead of prompting"
        echo "--update-shell-config     Always the shell config (e.g. .bashrc) if necessary"
        echo "--no-update-shell-config  Never update the shell config (e.g. .bashrc)"
        echo "--shell-config PATH       Use this file as your shell config when updating the shell config"
        echo "--shell SHELL             One of: bash, zsh, fish, sh. Installer will treat this as your shell. Use 'sh' for minimal posix shells such as ash"
        echo "--just-print-version      Make no changes to the system. The final line of stdout will be the version of dune that would have been installed"
        echo "--debug-override-url URL  Download dune tarball from given url (debugging only)"
        echo "--debug-tarball-dir DIR   Name of root directory inside tarball (debugging only)"
        echo "--debug-version-repo REPO Override the git repo url used to determine the latest version of dune (debugging only)"
    }

    install_root=""
    should_update_shell_config=""
    just_print_version="0"
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
            --just-print-version)
                just_print_version="1"
                ;;
            --debug-override-url)
                if [ "$#" -eq "0" ]; then
                    error "--debug-override-url must be passed an argument"
                fi
                debug_override_url="$1"
                shift
                ;;
            --debug-tarball-dir)
                if [ "$#" -eq "0" ]; then
                    error "--debug-tarball-dir must be passed an argument"
                fi
                debug_tarball_dir="$1"
                shift
                ;;
            --debug-version-repo)
                if [ "$#" -eq "0" ]; then
                    error "--debug-version-repo must be passed an argument"
                fi
                debug_version_repo="$1"
                shift
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
        version=$(latest_stable_binary_dune_version "${debug_version_repo:-"$dune_bin_git_url"}")
        echo
        info "The latest binary release of Dune was found to be $version."
        echo
    fi

    if [ "$just_print_version" = "1" ]; then
        echo
        info "Exiting due to --just-print-version. Would install Dune version:"
        echo
        echo "$version"
        exit
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
    tar_uri=${debug_override_url:-"$dune_bin_git_url/releases/download/$version/$tarball"}
    # The tarball is expected to contain a single directory with this name:
    tarball_dir=${debug_tarball_dir:-"dune-$version-$target"}

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
        info "Where would you like to install Dune? (enter index number or custom absolute path or leave blank for default)"
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
            '~'/*)
                install_root=$(echo "$choice" | sed "s#~#$HOME#")
                echo
                warn "Expanding $choice to $install_root"
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

    if [ -z "${debug_override_url+x}" ]; then
        curl_proto="=https"
    else
        # When using a debugging url the tarball might not be served with https.
        curl_proto="all"
    fi
    curl --fail --location --progress-bar \
        --proto "$curl_proto" --tlsv1.2 \
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

    if [ "$should_update_shell_config" = "n" ]; then
        # The remainder of the install script deals with updating the shell
        # config file. If the user indicated by command-line option that they
        # don't wish to do this, exit now.
        exit_message
        echo
        exit 0
    fi

    shell_name=${shell_name:-$(infer_shell_name)}
    env_dir="$install_root/share/dune/env"
    remove_opam_precmd_hook_posix="PROMPT_COMMAND=\"\$(echo \"\$PROMPT_COMMAND\" | tr ';' '\\n' | grep -v _opam_env_hook | paste -sd ';' -)\""
    case "$shell_name" in
        sh|ash|dash)
            shell_config_inferred="${shell_config:-$HOME/.profile}"
            env_file="$env_dir/env.sh"
            remove_opam_precmd_hook=$remove_opam_precmd_hook_posix
            ;;
        bash)
            bash_config_candidates="$HOME/.profile $HOME/.bash_profile $HOME/.bashrc"
            if [ "${XDG_CONFIG_HOME:-}" ]; then
                bash_config_candidates="$bash_config_candidates $XDG_CONFIG_HOME/profile $XDG_CONFIG_HOME/.profile $XDG_CONFIG_HOME/bash_profile $XDG_CONFIG_HOME/.bash_profile $XDG_CONFIG_HOME/bashrc $XDG_CONFIG_HOME/.bashrc"
            fi
            # When opam is initialized for a user using bash as their shell it adds
            # its configuration to ~/.profile by default. It's possible that users
            # manually specified a different bash config file such as ~/.bashrc or
            # ~/.bash_profile. Also some users may have moved the opam
            # configuration from one bash config file to another. It's necessary
            # that Dune's configuration be evaluated after opam's configuration. If
            # users have multiple different bash configurations present (it's quite
            # common to have both ~/.profile and ~/.bashrc with one sourcing the
            # other, for example), one way to make sure Dune is initialized after
            # opam is to append the Dune configuration to the end of which ever
            # bash config file also contains opam's configuration. This function
            # chooses the bash config file to add Dune's configuration to by
            # searching for a file containing Opam's configuration already, and
            # will select ~/.profile by default to match the behaviour of opam.
            for config in $bash_config_candidates; do
                if test -f "$config" && match=$(grep -Hn '\.opam/opam-init/init\.sh' "$config") ; then
                    shell_config_with_opam_init="$config"
                    bash_opam_init_match=$match
                    break
                fi
            done
            shell_config_inferred="${shell_config_with_opam_init:-$HOME/.profile}"
            env_file="$env_dir/env.bash"
            remove_opam_precmd_hook=$remove_opam_precmd_hook_posix
            ;;
        zsh)
            env_file="$env_dir/env.zsh"
            shell_config_inferred="$HOME/.zshrc"
            remove_opam_precmd_hook="autoload -Uz add-zsh-hook; add-zsh-hook -d precmd _opam_env_hook"
            ;;
        fish)
            env_file="$env_dir/env.fish"
            shell_config_inferred="$HOME/.config/fish/config.fish"
            remove_opam_precmd_hook="functions --erase __opam_env_export_eval"
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

    if [ -z "${shell_config+x}" ]; then
        info "The installer can modify your shell config file to set up your environment for running dune from your terminal."
        echo
        if [ -z "${bash_opam_init_match+x}" ]; then
            info "Based on your shell ($shell_name) the installer has inferred that your shell config file is: $shell_config_inferred"
        else
            info "Your shell is bash and the installer found an existing shell configuration for opam in $shell_config_inferred at:"
            echo
            echo
            info "$bash_opam_init_match"
            echo
            echo
            info "It's recommended to add Dune's configuration to the same file as the existing opam configuration."
        fi
        echo
        while [ -z "${shell_config+x}" ]; do
            echo
            info "Enter the absolute path of your shell config file or leave blank for default (no modification will be performed yet):"
            echo
            info_bold "[$shell_config_inferred] >"
            read -r choice < /dev/tty
            case "$choice" in
                "")
                    shell_config=$shell_config_inferred
                    ;;
                '~'/*)
                    shell_config=$(echo "$choice" | sed "s#~#$HOME#")
                    echo
                    warn "Expanding $choice to $shell_config"
                    ;;
                /*)
                    shell_config=$choice
                    ;;
                *)
                    echo
                    warn "Not an absolute path: $choice"
                    ;;
            esac
        done
        echo
    fi

    dune_env_call="__dune_env \"$(unsubst_home "$install_root")\""
    shell_config_code() {
        case "$shell_name" in
            fish)
                if_installed="if [ -f \"$(unsubst_home "$env_file")\" ]"
                end_if="end"
                ;;
            *)
                if_installed="if [ -f \"$(unsubst_home "$env_file")\" ]; then"
                end_if="fi"
                ;;
        esac

        code ""
        code "# BEGIN configuration from Dune installer"
        code "# This configuration must be placed after any opam configuration in your shell config file."
        code "# This performs several tasks to configure your shell for Dune:"
        code "#   - makes sure the dune executable is available in your \$PATH"
        code "#   - registers shell completions for dune if completions are available for your shell"
        code "#   - removes opam's pre-command hook because it would override Dune's shell configuration"
        code "$if_installed"
        # Use `.` rather than `source` because the former is more portable.
        code "    . \"$(unsubst_home "$env_file")\""
        code "    $dune_env_call"
        code "    $remove_opam_precmd_hook # remove opam's pre-command hook"
        code "$end_if"
        code "# END configuration from Dune installer"
    }

    if [ -f "$shell_config" ] && match=$(grep -Hn "$(echo "$dune_env_call" | sed 's#\$#\\$#')" "$shell_config"); then
        info "It appears your shell config file ($shell_config) is already set up correctly as it contains the line:"
        echo
        info "$match"
        echo
        echo
        info "Just in case it isn't, here are the lines that need run when your shell starts to initialize Dune:"
        echo
        shell_config_code
        echo
        exit_message
        echo
        exit 0
    fi

    info "To run dune from your terminal, you'll need to add the following lines to your shell config file ($shell_config):"
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
            mkdir -p "$(dirname "$shell_config")"
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
