{ pkgs, ... }: with pkgs; let paths = [

terraform
grafana
prometheus
# Add more re-exported nixpkgs here...

]; in symlinkJoin {
  name = "reexport";
  inherit paths;
}