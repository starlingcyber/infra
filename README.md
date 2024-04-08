# The Starling Cybernetics Flake

## Running operations

Pop into a `nix develop` environment (or let `direnv` do that for you) and you'll have access to all
the command line tooling needed to do operations, including Penumbra tools (`pcli`, `pd`,
`pclientd`), `cometbft`, `horcrux`, `tenderduty`, and more (to be added).

To get access to production deployment keys, run `./login`, which will authenticate with your local
1Password instance to load the relevant environment variables into a subshell. Note that this shell
will be running with a filter censoring output from directly containing secrets, but as a
side-effect of the filter, interactive TUI programs don't seem to work very well. Use this only as a
command interface to issue deployment commands.

## Adding packages

To add local packages to the flake, add nix files to `packages/` (see [the packages
README](./packages/README.md) for more details).
