{
  description = "The root nix flake for Starling Cybernetics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, crane, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {};
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; with builtins; let
          exported = import ./packages { inherit pkgs crane; };
        in rec {
          packages = exported // { all = symlinkJoin { name = "all"; paths = attrValues exported; }; };
          devShells.default = mkShell {
            name = "starling";
            buildInputs = attrValues exported;
          };

          # Permits unfree licenses, for example for terraform
          _module.args.pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    };
  };
}
