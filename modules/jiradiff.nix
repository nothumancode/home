{ inputs, pkgs, ... }:
{
  home.packages = [
    inputs.jiradiff.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
