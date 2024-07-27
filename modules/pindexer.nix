self: { config, lib, pkgs, ... }:

let
  cfg = config.services.penumbra.pindexer;
in {
  options.services.penumbra.pindexer = {
    enable = lib.mkEnableOption "Penumbra Indexer service";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.penumbra;
      description = "The package providing the pindexer command.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "penumbra-pindexer";
      description = "User account under which pindexer runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "penumbra-pindexer";
      description = "Group under which pindexer runs.";
    };

    srcDatabaseUrl = lib.mkOption {
      type = lib.types.str;
      description = "PostgreSQL database connection string for the source database with raw events.";
    };

    dstDatabaseUrl = lib.mkOption {
      type = lib.types.str;
      description = "PostgreSQL database connection string for the destination database with compiled data.";
    };

    genesisJson = lib.mkOption {
      type = lib.types.path;
      description = "File path for the genesis file to use when initializing the indexer.";
    };

    chainId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Filter for only events with this chain ID (optional).";
    };

    pollMs = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "The rate at which to poll for changes, in milliseconds (optional).";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Penumbra pindexer service user";
    };

    users.groups.${cfg.group} = {};

    systemd.services.penumbra-pindexer = {
      description = "Penumbra Pindexer Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = let
          pindexerCmd = "${cfg.package}/bin/pindexer";
          baseArgs = [
            "--src-database-url '${cfg.srcDatabaseUrl}'"
            "--dst-database-url '${cfg.dstDatabaseUrl}'"
            "--genesis-json '${cfg.genesisJson}'"
          ];
          chainIdArg = lib.optional (cfg.chainId != null) "--chain-id '${cfg.chainId}'";
          pollMsArg = lib.optional (cfg.pollMs != null) "--poll-ms ${toString cfg.pollMs}";
        in
          "${pindexerCmd} ${lib.escapeShellArgs (baseArgs ++ chainIdArg ++ pollMsArg)}";
        Restart = "always";
        RestartSec = "10s";
      };
    };
  };
}