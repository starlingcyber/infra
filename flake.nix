{
  description = "The root nix flake for Starling Cybernetics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    cometbft.url = "./cometbft";
    horcrux.url = "./horcrux";
  };

  outputs = { self, nixpkgs, flake-utils, cometbft, horcrux, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [];
          pkgs = import nixpkgs { inherit system overlays flake-utils; };
        in with pkgs; with pkgs.lib; {
          devShells.default = mkShell {};
          packages = {
            cometbft = cometbft.defaultPackage.${system};
            horcrux = horcrux.defaultPackage.${system};
          };
          defaultPackage = symlinkJoin {
            name = "starling-cybernetics-infra";
            paths = [ cometbft horcrux ];
          };
        }
      );
}
