# Locally configured packages (not available in nixpkgs)

Every package defined here is automatically imported into the `nix develop` shell environment, as
well as being automatically defined as a `package` output of the flake.

Any nix file in this directory will be detected and added as a package, and any directory containing
a `default.nix` file will be detected similarly (use the latter to add more complex packages that
require multiple files).

If a package is available in nixpkgs, prefer instead to add it to `../reexport.nix`.
