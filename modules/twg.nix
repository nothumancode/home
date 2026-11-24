{
  config,
  inputs,
  pkgs,
  ...
}:

{
  programs.twg = {
    enable = true;
    package = inputs.twg.packages.${pkgs.stdenv.hostPlatform.system}.twg;
    skillsDir = "${config.home.homeDirectory}/.agents/skills";
  };
}
