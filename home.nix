{ lib, pkgs, ... }:

{
  imports = [
    ./modules/shell.nix
    ./modules/packages.nix
    ./modules/secrets.nix
    ./modules/git.nix
    ./modules/neovim.nix
    ./modules/herdr.nix
    ./modules/mcp.nix
    ./modules/agents.nix
    ./modules/pi.nix
    ./modules/claude.nix
  ];

  # home.username and home.homeDirectory come from flake.nix.
  home.stateVersion = "26.05";

  # Use ~/.config, ~/.local/share and ~/.cache on every platform, macOS included.
  xdg.enable = true;

  # Ubuntu, Debian, WSL and other distributions that are not NixOS.
  targets.genericLinux.enable = lib.mkDefault pkgs.stdenv.hostPlatform.isLinux;
  targets.genericLinux.gpu.enable = false; # This is a terminal environment.

  programs.home-manager.enable = true;
}
