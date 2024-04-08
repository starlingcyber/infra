{ pkgs ? import <nixpkgs> {}, ... }: let

name = "tenderduty";
owner = "blockpane";
repo = "tenderduty";
version = "2.2.1";
hash = "sha256-pPOWPQJe6Tq/P90duGccSI1lLUKbLkFLknDazHg+VOw=";
vendorHash = "sha256-l8asIX6K+wWhjOBsJsZnW9/xj6+zCwtYIrEMcfYz+fw=";

in with pkgs; with pkgs.lib;

(buildGoModule rec {
  pname = name;
  inherit version vendorHash;
  src = fetchFromGitHub {
    inherit owner repo hash;
    rev = "v${version}";
  };
}).overrideAttrs (_: { doCheck = false; }) # Disable tests to improve build times
