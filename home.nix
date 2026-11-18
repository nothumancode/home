{ lib, pkgs, ... }:

let
  withDotenv =
    package: envFile:
    pkgs.symlinkJoin {
      pname = "${package.pname}-dotenv";
      inherit (package) version meta;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        launcher="$out/bin/${package.meta.mainProgram}"
        rm "$launcher"
        makeWrapper ${lib.getExe pkgs.dotenvx} "$launcher" \
          --add-flags "run --quiet -o -f ${envFile} -- ${lib.getExe package}"
      '';
    };
in
{
  imports = [
    ./modules/bash.nix
    ./modules/git.nix
    ./modules/neovim.nix
    ./modules/herdr.nix
    ./modules/mcp.nix
    ./modules/pi.nix
    ./modules/claude.nix
  ];

  home.username = "rodat";
  home.homeDirectory = "/home/rodat";
  home.stateVersion = "26.05";

  programs.claude-code.package = withDotenv pkgs.claude-code ./secrets/claude.env;
  programs.pi-coding-agent.package = withDotenv pkgs.pi-coding-agent ./secrets/pi.env;

  home.packages = [
    pkgs.cachix
    pkgs.dotenvx
    pkgs.git
    pkgs.gh
    pkgs.nixfmt
    pkgs.nixfmt-tree
    pkgs.nodejs_24
    pkgs.python313
    pkgs.uv
    pkgs.jq
    pkgs.ripgrep
    pkgs.fd
    pkgs.shfmt
  ];

  programs.home-manager.enable = true;
}
