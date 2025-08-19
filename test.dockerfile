# Dockerfile to exercise the install script in various scenarios. Build the
# dockerfile to run the test. This dockerfile has multiple stages were each
# test is a different stage. In order for docker to run all the stages when
# building the dockerfile, the final stage must depend on all previous stages.
#
# When adding a new test, name the stage testN add a line like:
# COPY --from=testN /install.sh .
# ...to the final stage.


FROM alpine:3.22.0 AS base
COPY install.sh .
ENV DUNE_VERSION="3.19.1"

###############################################################################
# Use the install script to install Dune system-wide and assert some facts to
# confirm that the installation succeeded.
FROM base AS test1
RUN apk update && apk add curl

# Install dune system-wide using the install script:
RUN ./install.sh $DUNE_VERSION --install-root /usr --no-update-shell-config

# Test that dune was installed to the expected location:
RUN test $(which dune) = "/usr/bin/dune"

# Test that the installed dune can be executed and that it reports being the
# expected version:
RUN test $(dune --version) = "$DUNE_VERSION"



###############################################################################
# Install dune having the script first look up the latest released version of
# dune.
FROM base AS test2
RUN apk update && apk add curl git

# Install dune system-wide using the install script:
RUN /install.sh --install-root /usr --no-update-shell-config

# Test that dune was installed to the expected location:
RUN test $(which dune) = "/usr/bin/dune"



###############################################################################
# Test that the install script can handle a user entering a path beginning with
# '~` at the prompt for install directory.
FROM base AS test3
RUN apk update && apk add curl expect

RUN adduser -D user
USER user
WORKDIR /home/user
COPY interactive_generic.tcl .

# Run the interactive installer using expect to enter text at interactive
# prompts.
RUN ./interactive_generic.tcl /install.sh "$DUNE_VERSION" '~/.local' ''
RUN test -f ~/.local/bin/dune



###############################################################################
# Test that dune can be installed alongside opam, and prevents opam's shell
# hook from interfering with PATH such that the install script's instance of
# dune takes precedence. This test uses bash as the login shell. Shell commands
# are run with `bash --login` so that ~/.profile or ~/.bash_profile is loaded
# into the shell.
FROM base AS test4
RUN apk update && apk add bash curl expect rsync git make pkgconf clang

# Install opam from its binary distribution
RUN curl -fsSL https://opam.ocaml.org/install.sh > install_opam.sh && yes '' | sh install_opam.sh

# Create a user
ENV SHELL=/bin/bash
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Initialize opam for the user and install dune in their default switch using
# opam
RUN $SHELL --login -c 'opam init --disable-sandbox --auto-setup'
RUN $SHELL --login -c 'opam install dune'

# Before the binary distro of dune is installed, 'dune' refers to the instance
# installed by opam.
RUN $SHELL --login -c 'test $(which dune) = "/home/user/.opam/default/bin/dune"'

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL --login -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a bash login shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL --login -c 'test $(which dune) = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed alongside opam, and prevents opam's shell
# hook from interfering with PATH such that the install script's instance of
# dune takes precedence. This test uses zsh as the login shell. Note that each
# command is run inside an interactive zsh shell. Zsh does not source the
# .zshrc file unless it's running an interactive shell, and opam and Dune both
# put their configurations in .zshrc so the environments for both only work
# correctly inside an interactive shell. Shell commands are run with `zsh
# --interactive` so that ~/.zshrc is loaded into the shell.
FROM base AS test5
RUN apk update && apk add zsh curl expect rsync git make pkgconf clang

# Install opam from its binary distribution
RUN curl -fsSL https://opam.ocaml.org/install.sh > install_opam.sh && yes '' | sh install_opam.sh

# Create a user
ENV SHELL=/bin/zsh
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Initialize opam for the user and install dune in their default switch using
# opam
RUN $SHELL --interactive -c 'opam init --disable-sandbox --auto-setup'
RUN $SHELL --interactive -c 'opam install dune'

# Before the binary distro of dune is installed, 'dune' refers to the instance
# installed by opam.
RUN $SHELL --interactive -c 'test $(which dune) = "/home/user/.opam/default/bin/dune"'

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL --interactive -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a zsh interactive shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL --interactive -c 'test $(which dune) = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed alongside opam, and prevents opam's shell
# hook from interfering with PATH such that the install script's instance of
# dune takes precedence. This test uses fish as the login shell.
FROM base AS test6
RUN apk update && apk add fish curl expect rsync git make pkgconf clang

# Install opam from its binary distribution
RUN curl -fsSL https://opam.ocaml.org/install.sh > install_opam.sh && yes '' | sh install_opam.sh

# Create a user
ENV SHELL=/usr/bin/fish
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Initialize opam for the user and install dune in their default switch using
# opam
RUN $SHELL -c 'opam init --disable-sandbox --auto-setup'
RUN $SHELL -c 'opam install dune'

# Before the binary distro of dune is installed, 'dune' refers to the instance
# installed by opam.
RUN $SHELL -c 'test $(which dune) = "/home/user/.opam/default/bin/dune"'

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a fish shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL -c 'test $(which dune) = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed alongside opam, and prevents opam's shell
# hook from interfering with PATH such that the install script's instance of
# dune takes precedence. This test uses sh as the login shell.
FROM base AS test7
RUN apk update && apk add curl expect rsync git make pkgconf clang

# Install opam from its binary distribution
RUN curl -fsSL https://opam.ocaml.org/install.sh > install_opam.sh && yes '' | sh install_opam.sh

# Create a user
ENV SHELL=/bin/sh
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Initialize opam for the user and install dune in their default switch using
# opam
RUN $SHELL -c 'opam init --disable-sandbox --auto-setup'
RUN $SHELL -c 'opam install dune'

# Before the binary distro of dune is installed, 'dune' refers to the instance
# installed by opam.
RUN $SHELL --login -c 'test "$(which dune)" = "/home/user/.opam/default/bin/dune"'

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL --login -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a sh shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL --login -c 'test "$(which dune)" = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed in the absence of opam when the login shell
# is bash.
FROM base AS test8
RUN apk update && apk add bash curl expect

# Create a user
ENV SHELL=/bin/bash
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL --login -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a bash login shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL --login -c 'test $(which dune) = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed in the absence of opam when the login shell
# is zsh.
FROM base AS test9
RUN apk update && apk add zsh curl expect

# Create a user
ENV SHELL=/bin/zsh
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL --interactive -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a zsh interactive shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL --interactive -c 'test $(which dune) = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed in the absence of opam when the login shell
# is fish.
FROM base AS test10
RUN apk update && apk add fish curl expect

# Create a user
ENV SHELL=/usr/bin/fish
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a fish shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL -c 'test $(which dune) = "/home/user/.local/bin/dune"'



###############################################################################
# Test that dune can be installed in the absence of opam when the login shell
# is sh.
FROM base AS test11
RUN apk update && apk add curl expect

# Create a user
ENV SHELL=/bin/sh
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Install dune using the interactive installer taking the default option at
# each prompt.
COPY interactive_generic.tcl .
RUN $SHELL --login -c './interactive_generic.tcl /install.sh $DUNE_VERSION "" ""'

# Confirm that inside a sh shell, 'dune' now refers to the instance
# installed by the install script.
RUN $SHELL --login -c 'test "$(which dune)" = "/home/user/.local/bin/dune"'



###############################################################################
# Test the options to override the tarball url and directory name. These flags
# can be used to install dune from a tarball at an arbitrary url, so just point
# them at the official release anyway as this will still exercise the logic for
# downloading dune from a url passed on the command-line.
FROM base AS test12
RUN apk update && apk add curl

# Install dune system-wide using the install script:
RUN ./install.sh $DUNE_VERSION --install-root /usr --no-update-shell-config \
    --debug-override-url https://github.com/ocaml-dune/dune-bin/releases/download/3.19.1/dune-3.19.1-x86_64-unknown-linux-musl.tar.gz \
    --debug-tarball-dir dune-3.19.1-x86_64-unknown-linux-musl

# Test that dune was installed to the expected location:
RUN test $(which dune) = "/usr/bin/dune"

# Test that the installed dune can be executed and that it reports being the
# expected version:
RUN test $(dune --version) = "$DUNE_VERSION"



###############################################################################
# Test that the modied shell config can still be loaded successfully if dune is
# no longer installed when the shell is bash.
FROM base AS test13
RUN apk update && apk add curl expect bash
ENV DUNE_VERSION="3.19.1"

ENV SHELL=/bin/bash
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Make the shell config exit with an error when an error is first encountered
RUN echo 'set -e' > ~/.profile

# Install dune and check that it worked
RUN /install.sh $DUNE_VERSION --install-root ~/.local --shell-config ~/.profile --update-shell-config

# Run the shell config as a script as a sanity check to test that it runs
# successfully while dune is installed.
RUN $SHELL .profile

# Uninstall dune
RUN rm -rf .local

# Make sure the shell config can still be executed despite dune not being
# installed.
RUN $SHELL .profile



###############################################################################
# Test that the modied shell config can still be loaded successfully if dune is
# no longer installed when the shell is zsh.
FROM base AS test14
RUN apk update && apk add curl expect zsh
ENV DUNE_VERSION="3.19.1"

ENV SHELL=/bin/zsh
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Make the shell config exit with an error when an error is first encountered
RUN echo 'set -e' > ~/.zshrc

# Install dune and check that it worked
RUN /install.sh $DUNE_VERSION --install-root ~/.local --shell-config ~/.zshrc --update-shell-config

# Run the shell config as a script as a sanity check to test that it runs
# successfully while dune is installed.
RUN $SHELL .zshrc

# Uninstall dune
RUN rm -rf .local

# Make sure the shell config can still be executed despite dune not being
# installed.
RUN $SHELL .zshrc



###############################################################################
# Test that the modied shell config can still be loaded successfully if dune is
# no longer installed when the shell is fish.
FROM base AS test15
RUN apk update && apk add curl expect fish
ENV DUNE_VERSION="3.19.1"

ENV SHELL=/usr/bin/fish
RUN adduser -D -s $SHELL user
USER user
WORKDIR /home/user

# Install dune and check that it worked
RUN /install.sh $DUNE_VERSION --install-root ~/.local --shell-config ~/.config/fish/config.fish --update-shell-config

# Fish doesn't have an equivalent of bash's `set -e` so instead create a
# modified copy of the shell config which explicitly exits with an error if the
# source command fails.
RUN sed 's/^ *\(source\|\.\).*/& || exit 1/' .config/fish/config.fish > checked-config.fish

# Run the modified shell config as a script as a sanity check to test that it
# runs successfully while dune is installed.
RUN $SHELL checked-config.fish

# Uninstall dune
RUN rm -rf .local

# Make sure the modified shell config can still be executed despite dune not
# being installed.
RUN $SHELL checked-config.fish



###############################################################################
# Test the logic for choosing which version of dune to install. This test uses
# entirely fictional versions of dune to clarify that it does not look at the
# real dune repo.
FROM base AS test16
RUN apk update && apk add curl git

# Initialize a git repo whose tags will be used to indicate releases.
ENV GIT_COMMITTER_NAME=user
ENV GIT_COMMITTER_EMAIL=user@example.com
ENV GIT_AUTHOR_NAME=user
ENV GIT_AUTHOR_EMAIL=user@example.com
ENV GIT_AUTHOR_EMAIL=user@example.com
RUN git init /dune-versions
RUN git -C /dune-versions commit --allow-empty --message dummy

# When there is a single version, that version is installed.
RUN git -C /dune-versions tag 0.1.0 && \
    test $(./install.sh --just-print-version --debug-version-repo /dune-versions | tail -n1) = "0.1.0"

# When there are multiple versions, the latest version is installed.
RUN git -C /dune-versions tag 0.2.0 && \
    test $(./install.sh --just-print-version --debug-version-repo /dune-versions | tail -n1) = "0.2.0"

# When the most-recently released version is not the latest version (by version
# number), the installer will still choose the latest version.
RUN git -C /dune-versions tag 0.1.1 && \
    test $(./install.sh --just-print-version --debug-version-repo /dune-versions | tail -n1) = "0.2.0"

# When the latest version version is not the last version in alpabetical order,
# the installer will still choose the latest version.
RUN git -C /dune-versions tag 0.10.0 && \
    test $(./install.sh --just-print-version --debug-version-repo /dune-versions | tail -n1) = "0.10.0"

# When the latest version is not a stable version (indicated by additional text
# after the semver triple) then the installer will install the latest stable
# version.
RUN git -C /dune-versions tag 0.11.0_alpha && \
    test $(./install.sh --just-print-version --debug-version-repo /dune-versions | tail -n1) = "0.10.0"



###############################################################################
# Test that the install script correctly infers the shell when the SHELL
# environment variable is not set when the shell is sh.
FROM base AS test17
RUN apk update && apk add curl expect
COPY interactive_generic.tcl .
RUN adduser -D user
USER user
WORKDIR /home/user

# Run the interactive installer in a shell. The final ':' is a noop to force
# the installer to run in a child process of bash, preventing the shell from
# exec-ing into expect instead. This simulates running the interactive
# installer from the command-line.
RUN sh -c "/interactive_generic.tcl /install.sh $DUNE_VERSION '' ''; :"
RUN grep env\.sh ~/.profile



###############################################################################
#Test that the install script correctly infers the shell when the SHELL
#environment variable is not set when the shell is ash (a minimal posix shell
#which should be handled the same as sh).
FROM base AS test18
RUN apk update && apk add curl expect
COPY interactive_generic.tcl .
RUN adduser -D user
USER user
WORKDIR /home/user

# Run the interactive installer in a shell. The final ':' is a noop to force
# the installer to run in a child process of bash, preventing the shell from
# exec-ing into expect instead. This simulates running the interactive
# installer from the command-line.
RUN ash -c "/interactive_generic.tcl /install.sh $DUNE_VERSION '' ''; :"
RUN grep env\.sh ~/.profile



###############################################################################
# Test that the install script correctly infers the shell when the SHELL
# environment variable is not set when the shell is dash (a minimal posix shell
# which should be handled the same as sh).
FROM base AS test19
RUN apk update && apk add curl expect dash
COPY interactive_generic.tcl .
RUN adduser -D user
USER user
WORKDIR /home/user

# Run the interactive installer in a shell. The final ':' is a noop to force
# the installer to run in a child process of bash, preventing the shell from
# exec-ing into expect instead. This simulates running the interactive
# installer from the command-line.
RUN dash -c "/interactive_generic.tcl /install.sh $DUNE_VERSION '' ''; :"
RUN grep env\.sh ~/.profile



###############################################################################
# Test that the install script correctly infers the shell when the SHELL
# environment variable is not set when the shell is bash.
FROM base AS test20
RUN apk update && apk add curl expect bash
COPY interactive_generic.tcl .
RUN adduser -D user
USER user
WORKDIR /home/user

# Run the interactive installer in a shell. The final ':' is a noop to force
# the installer to run in a child process of bash, preventing the shell from
# exec-ing into expect instead. This simulates running the interactive
# installer from the command-line.
RUN bash -c "/interactive_generic.tcl /install.sh $DUNE_VERSION '' ''; :"
RUN grep env\.bash ~/.profile



###############################################################################
# Test that the install script correctly infers the shell when the SHELL
# environment variable is not set when the shell is zsh.
FROM base AS test21
RUN apk update && apk add curl expect zsh
COPY interactive_generic.tcl .
RUN adduser -D user
USER user
WORKDIR /home/user

# Run the interactive installer in a shell. The final ':' is a noop to force
# the installer to run in a child process of bash, preventing the shell from
# exec-ing into expect instead. This simulates running the interactive
# installer from the command-line.
RUN zsh -c "/interactive_generic.tcl /install.sh $DUNE_VERSION '' ''; :"
RUN grep env\.zsh ~/.zshrc



###############################################################################
# Test that the install script correctly infers the shell when the SHELL
# environment variable is not set when the shell is fish.
FROM base AS test22
RUN apk update && apk add curl expect fish
COPY interactive_generic.tcl .
RUN adduser -D user
USER user
WORKDIR /home/user

# Run the interactive installer in a shell. The final ':' is a noop to force
# the installer to run in a child process of bash, preventing the shell from
# exec-ing into expect instead. This simulates running the interactive
# installer from the command-line.
RUN fish -c "/interactive_generic.tcl /install.sh $DUNE_VERSION '' ''; :"
RUN grep env\.fish ~/.config/fish/config.fish



###############################################################################
# Final stage that copies the install scripts from the previous stage to force
# them to be rerun after the script changes. Docker won't rerun stages which
# don't affect the final stage, even if their inputs change.
FROM scratch
COPY --from=test1 /install.sh .
COPY --from=test2 /install.sh .
COPY --from=test3 /install.sh .
COPY --from=test4 /install.sh .
COPY --from=test5 /install.sh .
COPY --from=test6 /install.sh .
COPY --from=test7 /install.sh .
COPY --from=test8 /install.sh .
COPY --from=test9 /install.sh .
COPY --from=test10 /install.sh .
COPY --from=test11 /install.sh .
COPY --from=test12 /install.sh .
COPY --from=test13 /install.sh .
COPY --from=test14 /install.sh .
COPY --from=test15 /install.sh .
COPY --from=test16 /install.sh .
COPY --from=test17 /install.sh .
COPY --from=test18 /install.sh .
COPY --from=test19 /install.sh .
COPY --from=test20 /install.sh .
COPY --from=test21 /install.sh .
COPY --from=test22 /install.sh .
