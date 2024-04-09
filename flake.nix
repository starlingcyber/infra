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
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; with builtins; rec {
          packages = import ./packages { inherit pkgs crane; };
          devShells.default = mkShell {
            name = "starling";
            buildInputs = attrValues packages;
          };

          # Permits unfree licenses, for example for terraform
          _module.args.pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    };
  };
}
