{ pkgs, ... }: let

name = "cometbft";
owner = "cometbft";
repo = "cometbft";
version = "0.37.15";
hash = "sha256-sX3hehsMNWWiQYbepMcdVoUAqz+lK4x76/ohjGb/J08=";
vendorHash = "sha256-F6km3YpvfdpPeIJB1FwA5lQvPda11odny0EHPD8B6kw=";

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
