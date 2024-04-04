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
      systems = [ "x86_64-linux" ];
      flake = {};
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; let
          cometbft = callPackage ./cometbft.nix { inherit pkgs; };
          horcrux = callPackage ./horcrux.nix { inherit pkgs; };
          penumbra = callPackage ./penumbra.nix { inherit pkgs crane; };
        in {
          devShells.default = callPackage ./shell.nix {
            inherit pkgs cometbft horcrux penumbra;
          };
          packages = {
            inherit cometbft horcrux penumbra;
            default = symlinkJoin {
              name = "starling-cybernetics-infra";
              paths = [ cometbft horcrux penumbra ];
            };
          };
          apps = let mkApp = program: { type = "app"; inherit program; }; in {
            pd = mkApp "${penumbra}/bin/pd";
            pcli = mkApp "${penumbra}/bin/pcli";
            pclientd = mkApp "${penumbra}/bin/pclientd";
          };

          # Permits unfree licenses, thank you to <https://jamesconroyfinn.com/til/flake-parts-and-unfree-packages>
          _module.args.pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    };
  };
}
