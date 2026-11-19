{ pkgs, ... }:

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

  home.packages = [
    pkgs.age
    pkgs.cachix
    pkgs.doppler
    pkgs.git
    pkgs.gh
    pkgs.nixfmt
    pkgs.nixfmt-tree
    pkgs.nodejs_24
    pkgs.python313
    pkgs.uv
    pkgs.jq
    pkgs.ripgrep
    pkgs.secretspec
    pkgs.fd
    pkgs.shfmt
  ];

  programs.direnv.enable = true;
  programs.home-manager.enable = true;
}
