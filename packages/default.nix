inputs @ { pkgs ? import <nixpkgs> {}, ... }:

with builtins;
with pkgs;
with lib;

let
  nixFile = hasSuffix ".nix";
  notDefaultNixFile = path: path != "default.nix";
  directoryContents = attrNames (readDir ./.);
  packageNames =
    map
      (removeSuffix ".nix")
      (filter (name: nixFile name && notDefaultNixFile name) directoryContents);
  mkPackage = name: { inherit name; value = callPackage ./${name}.nix inputs; };
in map mkPackage packageNames