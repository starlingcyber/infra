self: { config, pkgs, lib, ...  }:

with lib; with self.lib.util; let
  cfg = config.services.penumbra.pd;

  # Shorthand for the package, used below
  penumbra = self.packages.${pkgs.system}.penumbra;
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
  };

  config = mkIf cfg.enable {
    # Require that the CometBFT service is enabled, because `pd` won't do anything without it
    services.cometbft = {
      enable = true;
      genesisFile = cfg.genesisFile;
    };

    # Add the penumbra package to the system
    environment.systemPackages = [ penumbra ];

    systemd.services.${cfg.serviceName} = {
      wantedBy = ["multi-user.target"];
      wants = [ "network-online.target" "${cometbft.serviceName}.service" ];
      serviceConfig = {
        Restart = "on-failure";
        # This creates a directory at `/var/lib/${cfg.serviceName}` unconditionally, though it may
        # not actually be used if the data directory is overridden:
        StateDirectory = cfg.serviceName;
        StateDirectoryMode = "0600";
        ExecStart = ''
          ${pkgs.bash}/bin/bash -c \
            "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir} && \
             ${pkgs.coreutils}/bin/chmod 0600 ${cfg.dataDir} && \
             ${penumbra}/bin/pd start --home ${cfg.dataDir}"
        '';
        # Raise filehandle limit for tower-abci
        LimitNOFILE = 65536;
      } // sandboxSystemd {
        # This permits write access only to the chosen data directory
        writeDirs = [ cfg.dataDir ];
        # This permits network access only to these address families
        addressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };
  };
}
