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
