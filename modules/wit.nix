{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.wit.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
