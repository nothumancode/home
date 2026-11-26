{
  config,
  inputs,
  lib,
  pkgs,
  withDopplerSecrets,
  ...
}:

{
  programs.twg = {
    enable = true;
    package = withDopplerSecrets {
      name = "twg";
      project = "tools";
      config = "atlassian";
      program = lib.getExe inputs.twg.packages.${pkgs.stdenv.hostPlatform.system}.twg;
    };
    skillsDir = "${config.home.homeDirectory}/.agents/skills";
  };
}
