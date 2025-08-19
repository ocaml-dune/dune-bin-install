# Changelog

## v2

### Fixed

- Handle the case when the `$SHELL` variable is unset (#13)
- Make sure directory containing shell config exists before updating shell
  config (#10)
- Remove opam's shell hooks if present, which would have caused any dune
  installed with opam to be run instead of the dune installed by this script
  when running `dune` in the terminal. (#14)
- Prevent error when sourcing modified shell config when dune binary distro is
  not installed (#18)
- When the version number is omitted, choose the latest _stable_ version of
  dune (#21).
- Infer the user's shell when from the parent process's command when the
  `$SHELL` environment variable is unset (#25).

### Added

- Look up latest version if no version was specified (#7)
- Add debugging options to override the url (#15)
- Load env script for minimal posix shells such as ash and dash (#17)

### Changed

- Clarify that pressing enter takes the default value (#9)
- Include shell config filename when printing existing dune config (#12)
- Allow paths beginning with '~' to be entered at install root prompt (#11)

## v1

### Fixed

- Fix bug where install script assumed `$shell` to initially be unset, which is
  not always true (#5)

### Added

### Changed

## v0

### Fixed

### Added

- Initialize project
- Allow command-line arguments to be passed to run installer non-interactively (#2)
- Integration tests (#3)

### Changed
