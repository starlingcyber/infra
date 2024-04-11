self: {
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.penumbra.services.pd;
in {
  imports = [];

  options.penumbra.services.pd = {
    enable = mkEnableOption "Enables the Penumbra fullnode daemon";
  };

  config = mkIf cfg.enable {
    systemd.services."penumbra.pd" = {
      wantedBy = ["multi-user.target"];
      serviceConfig = let
        pkg = self.packages.${pkgs.system}.penumbra;
      in {
        Restart = "on-failure";
        ExecStart = "${pkg}/bin/pd";
        # TODO...
      };
    };
  };
}
