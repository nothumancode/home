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
      program = lib.getExe inputs.twg.packages.${pkgs.stdenv.hostPlatform.system}.twg;
      secrets = [
        "TWG_USER"
        "TWG_SITE"
        "TWG_TOKEN"
      ];
    };
    skillsDir = "${config.home.homeDirectory}/.agents/skills";
  };
}
