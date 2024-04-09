# The Starling Cybernetics Flake

## Running operations

Pop into a `nix develop` environment (or let `direnv` do that for you) and you'll have access to all
the command line tooling needed to do operations, including Penumbra tools (`pcli`, `pd`,
`pclientd`), `cometbft`, `horcrux`, `tenderduty`, and more (to be added).

To get access to production deployment keys, make a secondary environment file called `secret.env`
which uses [1Password secret
references](https://developer.1password.com/docs/cli/secrets-environment-variables#use-environment-env-files)
for its values. This will be automatically loaded by `direnv` when you enter the project directory
if you have the 1Password command line tools installed and configured.

## Adding packages

To add packages to the flake which are present in nixpkgs, add them to  `packages/reexport.nix`. To
add local packages to the flake (i.e. packages which cannot be found in `nixpkgs`, or which need to
be configured specially), add either a single nix file or a directory containing a `default.nix` to
the `packages` directory; the name of the file or directory will be used as the package name. See
[the packages README](./packages/README.md) for more details.
