{ pkgs, ... }: let

name = "cometbft";
owner = "cometbft";
repo = "cometbft";
version = "0.37.6";
hash = "sha256-OrihG/xBkgoQtNwyrXoznG571mXFtSdN21QKU8jQEUc=";
vendorHash = "sha256-2h8tXiy3YuKaJfMHTpbDpVKUO6xro+/DBg4PCE2KhsA=";

in with pkgs; with pkgs.lib;

(buildGoModule rec {
  pname = name;
  inherit version vendorHash;
  subPackages = [ "cmd/${name}" ];
  src = fetchFromGitHub {
    inherit owner repo hash;
    rev = "v${version}";
  };
}).overrideAttrs (_: { doCheck = false; }) # Disable tests to improve build times
