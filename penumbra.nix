{ pkgs ? import <nixpkgs> {}, crane, ... }: let

version = "0.71.0";
hash = "sha256-2mpyBEt44UlXm6hahJG9sHGxj6nzh7z9lnj/vLtAAzs=";

in let
  # Set up for Rust builds
  craneLib = crane.mkLib pkgs;

  # Important environment variables so that the build can find the necessary libraries
  PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
  LIBCLANG_PATH="${pkgs.libclang.lib}/lib";
in with pkgs; with pkgs.lib;

# All the Penumbra binaries
(craneLib.buildPackage {
  pname = "penumbra";
  src = cleanSourceWith {
    src = fetchFromGitHub {
      owner = "penumbra-zone";
      repo = "penumbra";
      rev = "v${version}";
      sha256 = hash;
    };
    filter = path: type:
      # Retain proving and verification parameters, and no-lfs marker file ...
      (builtins.match ".*\.(no_lfs|param||bin)$" path != null) ||
      # ... as well as all the normal cargo source files:
      (craneLib.filterCargoSources path type);
  };
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ clang openssl ];
  inherit system PKG_CONFIG_PATH LIBCLANG_PATH;
  cargoExtraArgs = "-p pd -p pcli -p pclientd";
}).overrideAttrs (_: { doCheck = false; }) # Disable tests to improve build times