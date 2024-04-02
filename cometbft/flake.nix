{
  description = "The CometBFT standalone consensus engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          cometBftRelease = {
            version = "0.37.5";
            sha256 = "sha256-wNVHsifieAtZgedavCEJLgG0kRDqUhG4Lk5ciTPoNzI=";
            vendorHash = "sha256-JPEGMa0HDesEtKFvgLUP2UfTB0DlParepE2p+n06Igc=";
          };

          overlays = [];
          pkgs = import nixpkgs { inherit system overlays; };
        in with pkgs; with pkgs.lib; let
          cometbft = (buildGoModule rec {
            pname = "cometbft";
            version = cometBftRelease.version;
            subPackages = [ "cmd/cometbft" ];
            src = fetchFromGitHub {
              owner = "cometbft";
              repo = "cometbft";
              rev = "v${cometBftRelease.version}";
              hash = cometBftRelease.sha256;
            };
            vendorHash = cometBftRelease.vendorHash;
            meta = {
              description = "CometBFT (fork of Tendermint Core): A distributed, Byzantine fault-tolerant, deterministic state machine replication engine";
              homepage = "https://github.com/cometbft/cometbft";
              license = licenses.asl20;
            };
          }).overrideAttrs (_: { doCheck = false; }); # Disable tests to improve build times
        in {
          packages = { inherit cometbft; };
          apps = {
            cometbft.type = "app";
            cometbft.program = "${cometbft}/bin/cometbft";
          };
          defaultPackage = cometbft;
        }
      );
}
