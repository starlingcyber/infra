{ pkgs, crane, ... }: let

name = "penumbra";
owner = "penumbra-zone";
repo = "penumbra";
version = "0.75.1";
hash = "sha256-Y/t90C3mNj7kxEPrh5E7SRxqxZaFn2aL4DIxyVWbUY0=";

in let
  # Set up for Rust builds
  craneLib = crane.mkLib pkgs;

  # Important environment variables so that the build can find the necessary libraries
  PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
  LIBCLANG_PATH="${pkgs.libclang.lib}/lib";
in with pkgs; with pkgs.lib;

# All the Penumbra binaries
(craneLib.buildPackage {
  pname = name;
  src = cleanSourceWith {
    src = (fetchgit {
      url = "https://github.com/${owner}/${repo}";
      rev = "v${version}";
      sha256 = hash;
      fetchLFS = true;
    });
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