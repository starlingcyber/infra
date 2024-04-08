{ pkgs ? import <nixpkgs> {}, ... }: with pkgs;

{
  inherit terraform prometheus grafana;
}