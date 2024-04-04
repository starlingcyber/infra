# The Starling Cybernetics Flake

## Running operations

Pop into a `nix develop` environment (or let `direnv` do that for you) and you'll have access to all
the command line tooling needed to do operations, including Penumbra tools (`pcli`, `pd`,
`pclientd`), `cometbft`, `horcrux`, and more (to be added).

## Adding packages

To add local packages to the flake, add nix files to `packages/` (see [the packages
README](./packages/README.md) for more details).
