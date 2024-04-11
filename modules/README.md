# NixOS modules for Penumbra infrastructure

This directory defines NixOS modules which can be enabled to run Penumbra related services.

## Adding modules

Any nix file in this directory will be detected and added as a module, and any directory containing
a `default.nix` file will be detected similarly (use the latter to add more complex packages that
require multiple files). Note that each module file *must* conform to the convention of taking
`self` (a reference to this flake itself) as its first function argument, so each file must start
something like:

```nix
self: { config, pkgs, lib, ...  }:
# Module definition goes here
```
