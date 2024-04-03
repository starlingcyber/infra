{
  description = "The root nix flake for Starling Cybernetics infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    crane = {
      url = "github:ipetkov/crane";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };

  outputs = inputs @ { self, nixpkgs, flake-parts, crane, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {};
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; let
          cometbft = callPackage ./cometbft.nix { inherit pkgs; };
          horcrux = callPackage ./horcrux.nix { inherit pkgs; };
          penumbra = callPackage ./penumbra.nix { inherit pkgs crane; };
        in {
          packages = {
            inherit cometbft horcrux penumbra;
            default = symlinkJoin {
              name = "starling-cybernetics-infra";
              paths = [ cometbft horcrux penumbra ];
            };
          };
          apps = {
            pd = {
              type = "app";
              program = "${penumbra}/bin/pd";
            };
            pcli = {
              type = "app";
              program = "${penumbra}/bin/pcli";
            };
            pclientd = {
              type = "app";
              program = "${penumbra}/bin/pclientd";
            };
          };
        };
    };
}
