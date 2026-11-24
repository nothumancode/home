{
  inputs,
  pkgs,
  ...
}:
{
  programs.brain = {
    package = inputs.brain.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
}
