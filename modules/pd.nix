self: { config, pkgs, lib, ...  }:

with lib; with self.lib.util; let
  cfg = config.services.penumbra.pd;

  # Shorthand for the packages, used below
  penumbra = self.packages.${pkgs.system}.penumbra;
  cometbft = self.packages.${pkgs.system}.cometbft;

  # Script to start the Penumbra daemon
  startScript = pkgs.writeShellScript "start-pd.sh" ''
    set -euxo
    ${penumbra}/bin/pd start \
      --home ${cfg.dataDir} \
      ${if cfg.grpc.autoHttps.enable then "--grpc-auto-https" else ""} \
      ${if cfg.grpc.autoHttps.production then "" else "--acme-staging"} \
      ${if cfg.metrics.port != null then "--metrics-bind 127.0.0.1:" + toString cfg.metrics.port else ""} \
      ${if cfg.grpc.bind != null then "--grpc-bind " + cfg.grpc.bind else ""} \
      --abci-bind ${config.services.cometbft.proxyApp.ip}:${toString config.services.cometbft.proxyApp.port} \
      --cometbft-addr http://${config.services.cometbft.rpc.ip}:${toString config.services.cometbft.rpc.port}
  '';

  # Script to bootstrap the node state from a snapshot, if this is enabled by the config
  bootstrapScript = pkgs.writeShellScript "bootstrap-pd.sh" ''
    set -euxo
    PATH="${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.curl}/bin:${pkgs.coreutils}/bin:$PATH"

    mkdir -p ${cfg.dataDir}
    chmod 0600 ${cfg.dataDir}
    if ${if cfg.bootstrap.enable then "true" else "false"} && [[ ! -d ${cfg.dataDir}/rocksdb ]]; then
      for URL in ${concatStringsSep " " cfg.bootstrap.snapshotUrls}; do
        if curl -L "$URL" | tar -xzC ${cfg.dataDir}; then
          for COMET_FILE in "genesis.json" "priv_validator_state.json"; do
            SRC="${cfg.dataDir}/$COMET_FILE"
            if [[ -f "$SRC" ]]; then
              DEST="${config.services.cometbft.homeDir}/config/$COMET_FILE"
              mkdir -p ${config.services.cometbft.homeDir}/config
              mv "$SRC" "$DEST"
            fi
          done
          exit 0
        else
          rm -rf ${cfg.dataDir}/*
        fi
      done
      exit 1
    fi
  '';
in {
  imports = [ self.nixosModules.cometbft ];

  options.services.penumbra.pd = {
    enable = mkEnableOption "Enables the Penumbra fullnode daemon and its CometBFT sidecar";

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/${cfg.serviceName}";
      description = "The directory where the Penumbra daemon will store its data";
    };

    serviceName = mkOption {
      type = types.str;
      default = "penumbra.pd";
      description = "The name of the Penumbra daemon service";
    };

    genesis.file = mkOption {
      type = types.path;
        description = "The path to the genesis file that will be used by the CometBFT service";
      default =
        if cfg.genesis.rpc.enable then let
          jsonRpcResponse = builtins.readFile (pkgs.fetchurl {
            url = cfg.genesis.rpc.url;
            sha256 = cfg.genesis.rpc.hash;
          });
          genesisJson =
            builtins.toJSON (builtins.fromJSON jsonRpcResponse).result.genesis;
          genesis = pkgs.writeTextFile {
            name = "genesis.json";
            text = genesisJson;
            executable = false;
            destination = "/genesis.json";
          };
        in "${genesis}/genesis.json"
        else throw "Either genesis.rpc must be enabled and configured, or genesis.file must be set";
    };

    genesis.rpc.enable = mkEnableOption "Whether to download the genesis file from a JSON-RPC endpoint";

    genesis.rpc.url = mkOption {
      type = types.str;
      description = "The URL from which to download the genesis file";
    };

    genesis.rpc.hash = mkOption {
      type = types.str;
      description = "The hash of the genesis file at the given URL";
    };

    metrics.port = mkOption {
      type = types.int;
      default = 9000;
      description = "The port on which the Penumbra daemon will expose Prometheus metrics";
    };

    grpc.bind = mkOption {
      type = types.str;
      default = if cfg.grpc.autoHttps.enable then "0.0.0.0:443" else "127.0.0.1:8080";
      description = "The address at which the Penumbra daemon will listen for gRPC connections";
    };

    grpc.autoHttps.enable =
      mkEnableOption "Whether to automatically enable HTTPS for the server using Let's Encrypt";

    grpc.autoHttps.production =
      mkEnableOption "Whether to use the production (rate-limited) Let's Encrypt ACME endpoint for the gRPC server";

    bootstrap.enable = mkEnableOption "Whether to bootstrap the node state from a snapshot";

    bootstrap.snapshotUrls = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The URLs from which to try downloading snapshot files";
    };

    RUST_LOG = mkOption {
      type = types.str;
      default = "info";
      description = "The log level for the Penumbra daemon";
    };
  };

  config = {
    # Add the penumbra package and cometbft to the system even if the service isn't enabled
    environment.systemPackages = [ penumbra cometbft ];
  } // mkIf cfg.enable {
    # Require that the CometBFT service is enabled, because `pd` won't do anything without it
    services.cometbft = {
      enable = true;
      genesis.file = cfg.genesis.file;
      # Ensure CometBFT only listens on localhost for the app and rpc, because it's only used by `pd`
      proxyApp.ip = "127.0.0.1";
      rpc.ip = "127.0.0.1";
    };

    systemd.services.${cfg.serviceName} = {
      # Don't start until the network is online
      wantedBy = [ "multi-user.target" ];
      # Require the CometBFT service and the bootstrap service (and fail if either fails)
      requires = [ "${config.services.cometbft.serviceName}.service" ];
      # Run the bootstrap script before starting the daemon
      preStart = "${bootstrapScript}";
      # Ensure that the Penumbra daemon is started before the CometBFT service
      before = [ "${config.services.cometbft.serviceName}.service" ];
      # Configuration of the service itself:
      serviceConfig = {
        Restart = "always";
        # This creates a directory at `/var/lib/${cfg.serviceName}` unconditionally, though it may
        # not actually be used if the data directory is overridden:
        StateDirectory = cfg.serviceName;
        StateDirectoryMode = "0600";
        ExecStart = startScript;
        # Raise filehandle limit for tower-abci
        LimitNOFILE = 65536;
        Environment = "RUST_LOG=${cfg.RUST_LOG}";
      } // sandboxSystemd {
        # This permits write access only to the chosen data directory
        writeDirs = [ cfg.dataDir ];
        # This permits network access only to these address families
        addressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };
  };
}
