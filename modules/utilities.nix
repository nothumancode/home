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
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nvd
    ];
    text = ''
      profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
      old_gen=""
      if [[ -e "$profile" ]]; then
        old_gen=$(readlink -f "$profile" || true)
      fi

      ${lib.getExe config.programs.home-manager.package} switch \
        -b backup --flake ${lib.escapeShellArg flakeRef} "$@"

      if [[ -n "$old_gen" && -e "$profile" ]]; then
        new_gen=$(readlink -f "$profile" || true)
        if [[ -n "$new_gen" && "$old_gen" != "$new_gen" ]]; then
          nvd diff "$old_gen" "$new_gen" || true
        fi
      fi
    '';
  };

  cache = pkgs.writeShellApplication {
    name = "cache";
    runtimeInputs = [
      pkgs.coreutils
    ];
    text = ''
      ${lib.getExe pkgs.cachix} watch-exec thehuman -- ${lib.getExe config.programs.home-manager.package} build --flake ${lib.escapeShellArg flakeRef}
    '';
  };
in
{
  programs = {
    bat = {
      enable = true;
      config = {
        style = "numbers,changes,header";
      };
    };

    eza = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      git = true;
      icons = "never";
      extraOptions = [ "--group-directories-first" ];
    };

    fd.enable = true;

    fzf = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border=rounded"
        "--info=inline-right"
      ];
      fileWidget = {
        command = "fd --type f --hidden --follow --exclude .git";
        options = [
          "--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null'"
        ];
      };
      changeDirWidget = {
        command = "fd --type d --hidden --follow --exclude .git";
        options = [
          "--preview 'eza --tree --level=2 --color=always --icons=never {} 2>/dev/null'"
        ];
      };
    };

    jq.enable = true;
    ripgrep.enable = true;

    uv = {
      enable = true;
      settings = {
        native-tls = true;
      };
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };

  home.packages =
    with pkgs;
    [
      rebuild
      cache

      # Language runtimes, package managers, and native build toolchain
      bun
      gcc
      gnumake
      go
      nodejs_24
      pkg-config
      pnpm
      python313
      typescript

      # Code intelligence, structured data, benchmarking, and task runners
      ast-grep
      hyperfine
      just
      lefthook
      poppler-utils
      qpdf
      sd
      sqlite
      tokei
      watchexec
      yq-go

      # Secrets, security scanning, and Nix workflow tooling
      age
      cachix
      doppler
      gitleaks
      nix-output-monitor
      nix-tree
      nvd
      sops

      # Terminal, network, archive, and diagnostic utilities
      btop
      curl
      dnsutils
      file
      glow
      gnutar
      lsof
      openssh
      rsync
      socat
      tree
      unzip
      wget
      xh
      xz
      zip
      zstd
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      bubblewrap
      iproute2
      psmisc
    ];
}
