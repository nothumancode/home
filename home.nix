{
  inputs,
  ...
}:

{
  imports = [
    inputs.capnshell.homeModules.default
    inputs.twg.homeManagerModules.default
    ./modules/bash.nix
    ./modules/claude-code.nix
    ./modules/codex.nix
    ./modules/dev-tools.nix
    ./modules/direnv.nix
    ./modules/fnox.nix
    ./modules/gh.nix
    ./modules/git.nix
    ./modules/neovim.nix
    ./modules/pi-coding-agent.nix
    ./modules/tmux.nix
    ./modules/twg.nix
    ./modules/utilities.nix
  ];

  home = {
    username = "rodat";
    homeDirectory = "/home/rodat";
    stateVersion = "26.05";

    sessionPath = [ "$HOME/.local/bin" ];

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      LESS = "-FRX";
      NODE_USE_SYSTEM_CA = "1";
      UV_SYSTEM_CERTS = "true";
      DOPPLER_PROJECT = "vault";
      DOPPLER_CONFIG = "prd";
    };
  };

  xdg = {
    enable = true;
    configFile = {
      # Mirror the flake unfree allowlist for ad-hoc nix-shell/impure commands.
      "nixpkgs/config.nix".text = ''
        {
          allowUnfreePredicate =
            pkg:
            builtins.elem (pkg.pname or (builtins.parseDrvName pkg.name).name) [
              "claude-code"
              "twg"
            ];
        }
      '';

      # Matching extra-trusted-substituters and extra-trusted-public-keys live in /etc/nix/nix.custom.conf.
      "nix/nix.conf".text = ''
        extra-substituters = https://thehuman.cachix.org https://nixpkgs-python.cachix.org
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

  programs.home-manager.enable = true;
}
