{
  description = "A threshold Tendermint signer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          horcruxRelease = {
            version = "3.3.0";
            sha256 = "sha256-ECrIFCJ0vIfuVfJmsGNRvwsf2lLLXhrZ5OCR300Qn0I=";
            vendorHash = "sha256-+fArmL2NwkSDo7jHN/wXu9mff0mXuXu2MtmXjuT1W0E=";
          };

          overlays = [];
          pkgs = import nixpkgs { inherit system overlays; };
        in with pkgs; with pkgs.lib; with builtins; let
          horcrux = (buildGoModule rec {
            pname = "horcrux";
            version = horcruxRelease.version;
            subPackages = [ "cmd/horcrux" ];
            src = filterSource
              # Workaround for bug preventing Go 1.22 from playing nicely with buildGoModule when
              # using go.work workspace -- we don't need it because we just want the executable
              (path: type: builtins.match ".*go.work$" path == null)
              (fetchFromGitHub {
                owner = "strangelove-ventures";
                repo = "horcrux";
                rev = "v${horcruxRelease.version}";
                hash = horcruxRelease.sha256;
              });
            vendorHash = horcruxRelease.vendorHash;
            meta = {
              description = "Horcrux is a multi-party-computation (MPC) signing service for CometBFT (Formerly known as Tendermint) nodes";
              homepage = "https://github.com/strangelove-ventures/horcrux";
              license = licenses.asl20;
            };
          }).overrideAttrs (_: {
            # Disable tests to improve build times
            doCheck = false;
          });
        in {
          packages = { inherit horcrux; };
          apps = {
            horcrux.type = "app";
            horcrux.program = "${horcrux}/bin/horcrux";
          };
          defaultPackage = horcrux;
        }
      );
}
