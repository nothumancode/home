{
  config,
  lib,
  pkgs,
  ...
}:
let
  flakeRef = "${config.xdg.configHome}/home-manager#${config.home.username}";

  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    text = ''
      exec ${lib.getExe config.programs.home-manager.package} switch \
        -b backup --flake ${lib.escapeShellArg flakeRef} "$@"
    '';
  };
in
{
  home.packages = [ rebuild ];
}
