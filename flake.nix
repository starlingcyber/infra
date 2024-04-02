{
  description = "The root nix flake for Starling Cybernetics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    cometbft.url = "./cometbft";
    horcrux.url = "./horcrux";
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, cometbft, horcrux, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # imports = [ cometbft.flakeModule horcrux.flakeModule ];
      flake =
        let
          overlays = [];
          pkgs = import nixpkgs { inherit overlays; };
        in with pkgs; with pkgs.lib; {
          devShells.default = mkShell {};
        };
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; {
          packages = {
            cometbft = cometbft.defaultPackage.${system};
            horcrux = horcrux.defaultPackage.${system};
            default = symlinkJoin {
              name = "starling-cybernetics-infra";
              paths = [ cometbft horcrux ];
            };
          };
        };
    };
}
