{
  description = "The root nix flake for Starling Cybernetics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [];
          pkgs = import nixpkgs { inherit system overlays; };
        in with pkgs; with pkgs.lib; let
        in rec {
          devShells.default = pkgs.mkShell {};
        }
      );
}
