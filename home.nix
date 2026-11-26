{
  cachixConfig,
  inputs,
  lib,
  unfreePackages,
  ...
}:

{
  imports = [
    inputs.wit.homeManagerModules.default
    inputs.capnshell.homeModules.default
    inputs.twg.homeManagerModules.default
    inputs.brain.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
    ./modules/bash.nix
    ./modules/brain.nix
    ./modules/claude-code.nix
    ./modules/codex.nix
    ./modules/dagu.nix
    ./modules/dev-tools.nix
    ./modules/direnv.nix
    ./modules/doppler.nix
    ./modules/gh.nix
    ./modules/git.nix
    ./modules/neovim.nix
    ./modules/nh.nix
    ./modules/pi-coding-agent.nix
    ./modules/tmux.nix
    ./modules/twg.nix
    ./modules/utilities.nix
  ];

  home = {
    stateVersion = "26.05";

    sessionPath = [ "$HOME/.local/bin" ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      LESS = "-FRX";
      NODE_USE_SYSTEM_CA = "1";
      UV_SYSTEM_CERTS = "true";
    };
  };

  # Every target is a non-NixOS Linux (WSL Ubuntu, Debian sandboxes), all headless.
  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
  };

  xdg = {
    enable = true;
    configFile = {
      # Mirror the flake unfree allowlist for ad-hoc nix-shell/impure commands.
      "nixpkgs/config.nix".text = ''
        {
          allowUnfreePredicate =
            pkg: builtins.elem (pkg.pname or (builtins.parseDrvName pkg.name).name) [ ${
              lib.concatMapStringsSep " " builtins.toJSON unfreePackages
            } ];
        }
      '';

      # Matching extra-trusted-substituters and extra-trusted-public-keys live in /etc/nix/nix.custom.conf.
      "nix/nix.conf".text = ''
        extra-substituters = ${builtins.concatStringsSep " " cachixConfig.substituters}
      '';
    };
  };

  # Pin nixpkgs in the user flake registry so nix shell/run nixpkgs#... resolves
  # immediately against the locked store input.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  services.cns = {
    enable = true;
    environment = {
      NODE_USE_SYSTEM_CA = "1";
      UV_SYSTEM_CERTS = "true";
    };
  };

  programs = {
    home-manager.enable = true;

    # command-not-found names the package for a missing command; `, <cmd>` runs it once.
    nix-index.enable = true;
    nix-index-database.comma.enable = true;
  };
}
