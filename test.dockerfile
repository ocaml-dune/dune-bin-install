# Dockerfile to exercise the install script in various scenarios. Build the
# dockerfile to run the test.

###############################################################################
# Use the install script to install Dune system-wide and assert some facts to
# confirm that the installation succeeded.
FROM alpine:3.22.0
RUN apk update && apk add curl
ENV DUNE_VERSION="3.19.1"
COPY install.sh .

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
FROM alpine:3.22.0
RUN apk update && apk add curl git
COPY install.sh .

# Install dune system-wide using the install script:
RUN ./install.sh --install-root /usr --no-update-shell-config

# Test that dune was installed to the expected location:
RUN test $(which dune) = "/usr/bin/dune"

###############################################################################
# Test that the install script can handle a user entering a path beginning with
# '~` at the prompt for install directory.
FROM alpine:3.22.0
RUN apk update && apk add curl expect
ENV DUNE_VERSION="3.19.1"

RUN adduser -D user
USER user
WORKDIR /home/user
COPY install.sh interactive_generic.tcl .

# Run the interactive installer using expect to enter text at interactive
# prompts.
RUN ./interactive_generic.tcl ./install.sh 3.19.1 '~/.local'
RUN test -f ~/.local/bin/dune
