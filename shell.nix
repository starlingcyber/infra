{ pkgs ? import <nixpkgs> {}, cometbft, horcrux, penumbra }:

with pkgs; mkShell {
  buildInputs = [
    terraform
    cometbft
    horcrux
    penumbra
  ];
}
