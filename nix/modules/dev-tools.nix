{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  packages = with pkgs; [
    deadnix
    nixfmt
    statix
    shfmt
    shellcheck
    ruff
    ty
    stylua
    prettier
    yamllint
    taplo
    hadolint
  ];

  extraCliPackages = with pkgs; [
    # Kanban `todomd` CLI
    inputs.kbtd.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Scoped to .github/workflows/*.y*ml in Neovim; available globally for CLI/agent checks.
    actionlint
    # Provides the treefmt-wrapped project formatter; never run as a single-buffer formatter.
    nixfmt-tree
  ];

in
{
  home.packages = lib.unique (packages ++ extraCliPackages);

  home.file.".editorconfig".source = ../../shared/editorconfig;

  programs.neovim.extraPackages = lib.mkIf config.programs.neovim.enable (
    packages ++ [ pkgs.actionlint ]
  );
  xdg.configFile."nvim/lua/dev_tools.lua" = lib.mkIf config.programs.neovim.enable {
    source = ../../shared/nvim/dev_tools.lua;
  };
}
