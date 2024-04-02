{ pkgs ? import <nixpkgs> {}, ... }:

let
  name = "cometbft";
  version = "0.37.5";
  hash = "sha256-wNVHsifieAtZgedavCEJLgG0kRDqUhG4Lk5ciTPoNzI=";
  vendorHash = "sha256-JPEGMa0HDesEtKFvgLUP2UfTB0DlParepE2p+n06Igc=";
in with pkgs; with pkgs.lib;

(buildGoModule rec {
  pname = name;
  inherit version vendorHash;
  subPackages = [ "cmd/${name}" ];
  src = fetchFromGitHub {
    owner = name;
    repo = name;
    rev = "v${version}";
    inherit hash;
  };
}).overrideAttrs (_: { doCheck = false; }) # Disable tests to improve build times
