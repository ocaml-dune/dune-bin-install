# Dune Binary Installer

## Install Dune

Paste this into your terminal to install Dune:
```
curl https://raw.githubusercontent.com/ocaml-dune/dune-bin-install/refs/heads/main/install.sh | sh -s 3.19.1
```

No installation of opam or OCaml is necessary. Dune will be installed under `~/.local` by default.

## Non-interactive Installation

By default the install script is interactive, prompting for the install location
and whether or not to update the shell config file. This information can be
specified on the command-line instead which prevents the script from prompting.
In some situations it's necessary to install Dune non-interactively, such as
when building a docker image. To do this, run the script with
`--install-root PATH` and one of `--update-shell-config` and
`--no-update-shell-config`.

For example to install Dune while building a docker image from a Dockerfile,
assuming `curl` is installed and the current user is root, one could use:
```dockerfile
RUN curl https://raw.githubusercontent.com/ocaml-dune/dune-bin-install/refs/heads/main/install.sh | sh -s 3.19.1 --install-root /usr --no-update-shell-config
```
Note the `--install-root /usr`, which causes dune to be installed system-wide,
with its executable installed to `/usr/bin/dune`. Since `/usr/bin` is almost
certainly already in `$PATH`, this will make the `dune` command available
without needing to modify the environment.
