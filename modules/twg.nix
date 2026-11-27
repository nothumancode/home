{
  config,
  inputs,
  lib,
  pkgs,
  dopplerLib,
  ...
}:

{
  programs.twg = {
    enable = true;
    package = dopplerLib.withSecrets {
      name = "twg";
      project = "tools";
      config = "atlassian";
      program = lib.getExe inputs.twg.packages.${pkgs.stdenv.hostPlatform.system}.twg;
    };
    skillsDir = "${config.home.homeDirectory}/.agents/skills";
  };
}
