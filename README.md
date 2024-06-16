# Nix packages and NixOS modules for Penumbra infrastructure

## Quick shell

Pop into a `nix develop` environment (or let `direnv` do that for you) and you'll have access to all
the command line tooling needed to do operations, including Penumbra tools (`pcli`, `pd`,
`pclientd`), `cometbft`, `horcrux`, `tenderduty`, and more (to be added).

## Adding packages

To add local packages to the flake (i.e. packages which cannot be found in `nixpkgs`, or which need
to be configured specially), add either a single nix file or a directory containing a `default.nix`
to the `packages` directory; the name of the file or directory will be used as the package name. See
[the packages README](./packages/README.md) for more details.
