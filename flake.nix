{
  description = "An opinionated flake providing software and services for Penumbra infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };

  nixConfig = {
    extra-substituters = ["https://cache.garnix.io"];
    extra-trusted-substituters = ["https://cache.garnix.io"];
    extra-trusted-public-keys = ["cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="];
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, crane, ... }:
    let util = import ./util.nix { inherit nixpkgs; }; in with util;
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake.nixosModules = importAll ./modules self;
      flake.lib = { inherit util; };
      systems = [ "x86_64-linux" ];
      perSystem = { pkgs, ... }:
        with pkgs; with builtins; let
          packages = importAll ./packages { inherit pkgs crane; };
          apps = {
            pd = "${packages.penumbra}/bin/pd";
            pcli = "${packages.penumbra}/bin/pcli";
            pclientd = "${packages.penumbra}/bin/pclientd";
            # Add any future Penumbra package commands here
          };
        in {
          devShells.default = mkShell { buildInputs = attrValues packages; };
          apps = mkApps apps;
          packages = packages // {
            default = symlinkJoin {
              name = "penumbra-default";
              paths = map (name: packages.${name})
                (filter (name: name != "default") (attrNames packages));
            };
          };
        };
    };
}
