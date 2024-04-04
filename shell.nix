{ pkgs ? import <nixpkgs> {}, packages }:

with pkgs; let extraPackages = [
  terraform
];

in with builtins; mkShell {
  PCLI_UNLEASH_DANGER = 1;
  buildInputs = extraPackages ++ builtins.attrValues packages;
}
