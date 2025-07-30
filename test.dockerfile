# Dockerfile that uses the install script to install Dune system-wide and
# asserts some facts to confirm that the installation succeeded. Build the
# dockerfile to run the test.
FROM alpine:3.22.0 AS builder
RUN apk update && apk add curl
ENV DUNE_VERSION="3.19.1"
COPY install.sh .

# Install dune system-wide using the install script:
RUN ./install.sh $DUNE_VERSION --install-root /usr --no-update-shell-config

# Test that dune was installed to the expected location:
RUN test $(which dune) = "/usr/bin/dune"

# Test that the installed dune can be executed and that it reports being the expected version:
RUN test $(dune --version) = "$DUNE_VERSION"
