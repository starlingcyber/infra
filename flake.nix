{
  description = "The root nix flake for Starling Cybernetics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake =
        let pkgs = import nixpkgs;
        in with pkgs; { devShells.default = mkShell {}; };
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; let
          cometbft = callPackage ./cometbft.nix { inherit pkgs; };
          horcrux = callPackage ./horcrux.nix { inherit pkgs; };
        in {
          packages = {
            inherit cometbft horcrux;
            default = symlinkJoin {
              name = "starling-cybernetics-infra";
              paths = [ cometbft horcrux ];
            };
          };
        };
    };
}
