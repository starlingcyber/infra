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
      perSystem = { config, self', inputs', pkgs, system, ... }:
        with pkgs; let
          externalPackages = {
            inherit terraform;
          };
        in with builtins; rec {
          packages = externalPackages // listToAttrs (callPackage ./packages { inherit pkgs crane; });
          devShells.default = mkShell {
            name = "starling";
            PCLI_UNLEASH_DANGER = 1;
            buildInputs = attrValues externalPackages ++ attrValues packages;
          };

          # Permits unfree licenses, thank you to <https://jamesconroyfinn.com/til/flake-parts-and-unfree-packages>
          _module.args.pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    };
  };
}
