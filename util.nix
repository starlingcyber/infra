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

  # Generate a template for a systemd service that runs a program in a reasonably sandboxed
  # environment so that it cannot easily damage the system, even if it is compromised, with
  # reasonable defaults that still permit most system services to run without issue.
  sandboxSystemd = {
    writeDirs ? [],
    execDirs ? [],
    accessHome ? false,
    addressFamilies ? [],
    allowExecMemory ? false,
  }: {
    # Only permit writes to `/run` (needed for mount points) so that an exploit cannot write to
    # any other part of the system
    ReadOnlyPaths = [ "/" ];
    # Explicitly allow access to the specified directories
    ReadWritePaths = [ "/run" ] ++ map (dir: "-${dir}") writeDirs;
    # Only allow execution from the Nix store (which is mounted read-only) so that an exploit
    # cannot execute arbitrary code that it writes to a writable directory
    NoExecPaths = [ "/" ];
    # Explicitly allow execution from the specified directories
    ExecPaths = [ "/nix/store" ] ++ map (dir: "-${dir}") execDirs;
    # Restrict what kinds of sockets can be bound
    RestrictAddressFamilies = addressFamilies;
    # Prevent privilege escalation
    NoNewPrivileges = "yes";
    RestrictSUIDSGID = "yes";
    PrivateUsers = "yes";
    # Don't allow access to any user home directories
    ProtectHome = if accessHome then "no" else "yes";
    # Protect parts of the system from access and modification
    ProtectSystem = "full";
    ProtectKernelLogs = "yes";
    ProtectKernelModules = "yes";
    ProtectKernelTunables = "yes";
    ProtectControlGroups = "yes";
    ProtectClock = "yes";
    ProtectHostname = "yes";
    PrivateTmp = "yes";
    RestrictRealtime = "yes";
    # Prevent dynamic code execution (and if everything is mounted noexec except the Nix store,
    # files written to disk by the service cannot be executed to get around this)
    MemoryDenyWriteExecute = if allowExecMemory then "no" else "yes";
  }
}