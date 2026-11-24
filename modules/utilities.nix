{
  cachixConfig,
  config,
  lib,
  pkgs,
  remoteFlake,
  ...
}:

let
  localFlakeDir = "${config.xdg.configHome}/home-manager";
  localFlakeRef = "${localFlakeDir}#${config.home.username}";
  remoteFlakeRef = "${remoteFlake}#${config.home.username}";

  hmSwitch = pkgs.writeShellApplication {
    name = "hm-switch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.nvd
    ];
    text = ''
      push=false
      remote=false
      args=()
      for arg in "$@"; do
        case "$arg" in
          --push)
            push=true
            ;;
          --remote)
            remote=true
            ;;
          *)
            args+=("$arg")
            ;;
        esac
      done

      ${cachixConfig.nixOptsShellSnippet}

      if [[ "$remote" == true || ! -f ${lib.escapeShellArg "${localFlakeDir}/flake.nix"} ]]; then
        flake_ref=${lib.escapeShellArg remoteFlakeRef}
        nix_opts+=(--refresh)
      else
        flake_ref=${lib.escapeShellArg localFlakeRef}
      fi

      profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
      old_gen=""
      if [[ -e "$profile" ]]; then
        old_gen=$(readlink -f "$profile" || true)
      fi

      ${lib.getExe config.programs.home-manager.package} switch \
        -b backup --flake "$flake_ref" "''${nix_opts[@]}" "''${args[@]}"

      new_gen=""
      if [[ -e "$profile" ]]; then
        new_gen=$(readlink -f "$profile" || true)
      fi

      if [[ -n "$old_gen" && -n "$new_gen" && "$old_gen" != "$new_gen" ]]; then
        nvd diff "$old_gen" "$new_gen" || true
      fi

      if [[ "$push" == true && -n "$new_gen" ]]; then
        ${lib.getExe pkgs.cachix} push thehuman "$new_gen"
      fi
    '';
  };

  hmFmt = pkgs.writeShellApplication {
    name = "hm-fmt";
    runtimeInputs = [
      pkgs.findutils
      pkgs.nixfmt
      pkgs.stylua
    ];
    text = ''
      repo=${lib.escapeShellArg localFlakeDir}
      if [[ ! -f "$repo/flake.nix" ]]; then
        echo "hm-fmt: no local checkout found at $repo" >&2
        exit 1
      fi
      cd "$repo"
      find . -name '*.nix' -print0 | xargs -0 nixfmt
      if [[ -d modules/neovim ]]; then
        stylua --no-editorconfig modules/neovim
      fi
    '';
  };

  hmCheck = pkgs.writeShellApplication {
    name = "hm-check";
    runtimeInputs = [
      pkgs.actionlint
      pkgs.deadnix
      pkgs.findutils
      pkgs.nixfmt
      pkgs.statix
      pkgs.stylua
    ];
    text = ''
      lint_only=false
      args=()
      for arg in "$@"; do
        if [[ "$arg" == "--lint" ]]; then
          lint_only=true
        else
          args+=("$arg")
        fi
      done

      repo=${lib.escapeShellArg localFlakeDir}
      if [[ ! -f "$repo/flake.nix" ]]; then
        echo "hm-check: no local checkout found at $repo" >&2
        exit 1
      fi
      cd "$repo"

      find . -name '*.nix' -print0 | xargs -0 nixfmt --check
      statix check .
      deadnix --fail .
      if [[ -d modules/neovim ]]; then
        stylua --no-editorconfig --check modules/neovim
      fi
      if [[ -d .github/workflows ]]; then
        actionlint
      fi

      if [[ "$lint_only" == true ]]; then
        exit 0
      fi

      nix flake check "''${args[@]}"
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
      hmCheck
      hmFmt
      hmSwitch

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
