self: { config, pkgs, lib, ...  }:

with lib; let
  cfg = config.penumbra.services.pd;
in {
  imports = [ self.nixosModules.cometbft ];

  options.penumbra.services.pd = {
    enable = mkEnableOption "Enables the Penumbra fullnode daemon and its CometBFT sidecar";

    home = mkOption {
      type = types.path;
      default = "/var/lib/penumbra/pd";
      description = "The directory where the Penumbra daemon will store its data";
    };
  };

  config = mkIf cfg.enable {
    # Require that the CometBFT service is enabled, because `pd` won't do anything without it
    services.penumbra.cometbft.enable = true;

    systemd.services."penumbra.pd" = {
      wantedBy = ["multi-user.target"];
      serviceConfig = let
        penumbra = self.packages.${pkgs.system}.penumbra;
        cometbft = self.packages.${pkgs.system}.cometbft;
      in {
        Restart = "on-failure";
        ExecStart = "${penumbra}/bin/pd";
        # TODO...
      };
    };
  };
}
