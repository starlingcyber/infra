{ pkgs ? import <nixpkgs> {}, localPackages }:

with pkgs; let extraPackages = [
  terraform
];

in with builtins; mkShell {
  PCLI_UNLEASH_DANGER = 1;
  buildInputs = extraPackages ++ map (a: a.value) localPackages;
}
