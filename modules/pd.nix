self: { config, pkgs, lib, ...  }:

with lib; with self.lib.util; let
  cfg = config.services.penumbra.pd;

  # Shorthand for the packages, used below
  penumbra = self.packages.${pkgs.system}.penumbra;
  cometbft = self.packages.${pkgs.system}.cometbft;
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

    genesisFile = mkOption {
      type = types.path;
      description = "The path to the genesis file that will be used by the CometBFT service";
    };

    metrics.port = mkOption {
      type = types.int;
      optional = true;
      description = "The port on which the Penumbra daemon will expose Prometheus metrics";
    };

    grpc.bind = mkOption {
      type = types.str;
      optional = true;
      description = "The address at which the Penumbra daemon will listen for gRPC connections";
    };

    grpc.autoHttps.enable =
      mkEnableOption "Whether to automatically enable HTTPS for the server using Let's Encrypt";

    grpc.autoHttps.production =
      mkEnableOption "Whether to use the production (rate-limited) Let's Encrypt ACME endpoint for the gRPC server";

    RUST_LOG = mkOption {
      type = types.str;
      default = "info";
      description = "The log level for the Penumbra daemon";
    };
  };

  config = mkIf cfg.enable {
    # Require that the CometBFT service is enabled, because `pd` won't do anything without it
    services.cometbft = {
      enable = true;
      genesisFile = cfg.genesisFile;
      # Ensure CometBFT only listens on localhost for the app and rpc, because it's only used by `pd`
      proxyApp.ip = "127.0.0.1";
      rpc.ip = "127.0.0.1";
    };

    # Add the penumbra package to the system
    environment.systemPackages = [ penumbra ];

    systemd.services.${cfg.serviceName} = {
      wantedBy = ["multi-user.target"];
      wants = [ "network-online.target" "${config.services.cometbft.serviceName}.service" ];
      serviceConfig = {
        Restart = "on-failure";
        # This creates a directory at `/var/lib/${cfg.serviceName}` unconditionally, though it may
        # not actually be used if the data directory is overridden:
        StateDirectory = cfg.serviceName;
        StateDirectoryMode = "0600";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c "\
            ${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir} && \
            ${pkgs.coreutils}/bin/chmod 0600 ${cfg.dataDir} && \
            ${penumbra}/bin/pd start \
              --home ${cfg.dataDir} \
              ${if cfg.grpc.autoHttps.enable then "--grpc-auto-https" else ""} \
              ${if cfg.grpc.autoHttps.production then "" else "--acme-staging"} \
              ${if cfg.metrics ? port then "--metrics-bind 127.0.0.1:" + toString cfg.metrics.port else ""} \
              ${if cfg.grpc ? bind then "--grpc-bind " + cfg.grpc.bind else ""} \
              --abci-bind ${config.services.cometbft.proxyApp.ip}:${toString config.services.cometbft.proxyApp.port} \
              --cometbft-addr ${config.services.cometbft.rpc.ip}:${toString config.services.cometbft.rpc.port} \
        "'';
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
