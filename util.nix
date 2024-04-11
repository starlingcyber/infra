{ nixpkgs, ... }:

# Automatically import all nix files in the current directory as individual packages. If any build
# gets complicated enough that it needs a separate directory, it can be placed in a subdirectory
# with a `default.nix` file, which will also be imported. Every package defined here will be
# available automatically in the `nix develop` shell, as well as defined as a buildable package
# target for the top level flake.

with builtins; with nixpkgs.lib;

rec {
  importAll = path: inputs: let
    directory = readDir path;
    files = filter (name: directory.${name} == "regular") (attrNames directory);
    directories = filter (name: directory.${name} == "directory") (attrNames directory);
    nixFile = hasSuffix ".nix";
    packagePaths =
      filter nixFile files ++
      filter (name: (readDir "${path}/${name}")."default.nix" == "regular") directories;
    mkPackage = name: {
      name = removeSuffix ".nix" name;
      value = import "${path}/${name}" inputs;
    };
    in listToAttrs (map mkPackage packagePaths);

  mkApp = name: program: { "${name}" = { type = "app"; inherit program; }; };

  mkApps = concatMapAttrs mkApp;
}