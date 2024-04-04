{ pkgs ? import <nixpkgs> {}, cometbft, horcrux, penumbra }:

with pkgs; mkShell {
  PCLI_UNLEASH_DANGER = 1;
  buildInputs = [
    terraform
    cometbft
    horcrux
    penumbra
  ];
}
