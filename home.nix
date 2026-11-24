{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.capnshell.homeModules.default
    ./modules/bash.nix
    ./modules/codex.nix
    ./modules/direnv.nix
    ./modules/dev-tools.nix
    ./modules/neovim.nix
    ./modules/fnox.nix
    ./modules/gh.nix
    ./modules/git.nix
    ./modules/pi-coding-agent.nix
    ./modules/utilities.nix
  ];

  home.username = "rodat";
  home.homeDirectory = "/home/rodat";
  home.stateVersion = "26.05";

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    inputs.capnshell.packages.${pkgs.stdenv.hostPlatform.system}.cns
    inputs.twg.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.cachix
    pkgs.devenv
    pkgs.direnv
    pkgs.doppler
    pkgs.fnox
    pkgs.jq
    pkgs.nodejs_24
    pkgs.ripgrep
    pkgs.python313
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/rodat/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  services.cns.enable = true;
  programs.home-manager.enable = true;
}
