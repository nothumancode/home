{
  config,
  lib,
  pkgs,
  ...
}:

let
  dopplerBin = lib.getExe' pkgs.doppler "doppler";
  ghBin = lib.getExe config.programs.gh.package;

  setupGithubAuth = pkgs.writeShellApplication {
    name = "setup-github-auth";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
    ];
    text = ''
      export XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome}
      export GH_CONFIG_DIR=${lib.escapeShellArg "${config.xdg.configHome}/gh"}

      export DOPPLER_BIN=${lib.escapeShellArg dopplerBin}
      export GH_BIN=${lib.escapeShellArg ghBin}
    ''
    + builtins.readFile ../../shared/bin/setup-github-auth;

  };
in
{
  programs.gh = {
    enable = true;

    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };

    settings = builtins.fromJSON (builtins.readFile ../../shared/gh/config.yml);
  };

  home.activation.setupGithubAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe setupGithubAuth}
  '';
}
