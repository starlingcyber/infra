{ pkgs, ... }: let

name = "horcrux";
owner = "strangelove-ventures";
repo = "horcrux";
version = "3.3.1";
hash = "sha256-AGLLe72/ZS4M2oEXULb0mWMqLUC+YYJTO8BkmcMQKQM=";
vendorHash = "sha256-+fArmL2NwkSDo7jHN/wXu9mff0mXuXu2MtmXjuT1W0E=";

in with pkgs; with pkgs.lib; with builtins;

(buildGoModule rec {
  pname = name;
  inherit version vendorHash;
  subPackages = [ "cmd/${name}" ];
  src = filterSource
    # Workaround for bug preventing Go 1.22 from playing nicely with buildGoModule when
    # using go.work workspace -- we don't need it because we just want the executable
    (path: type: builtins.match ".*go.work$" path == null)
    (fetchFromGitHub {
      inherit owner repo hash;
      rev = "v${version}";
    });
}).overrideAttrs (_: { doCheck = false; }) # Disable tests to improve build times
