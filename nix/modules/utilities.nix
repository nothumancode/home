{
  config,
  lib,
  pkgs,
  remoteFlake,
  ...
}:

let
  localFlakeDir = "${config.xdg.configHome}/home-manager";

  hmSwitch = pkgs.writeShellApplication {
    name = "hm-switch";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      push=false
      dry_run=false
      args=()
      for arg in "$@"; do
        case "$arg" in
          --push) push=true ;;
          -n | --dry)
            dry_run=true
            args+=("$arg")
            ;;
          *) args+=("$arg") ;;
        esac
      done

      if [[ -f ${lib.escapeShellArg "${localFlakeDir}/flake.nix"} ]]; then
        ${lib.getExe config.programs.nh.package} home switch -b backup ${lib.escapeShellArg localFlakeDir} "''${args[@]}"
      else
        # No checkout: run the flake's own switch app at the latest remote revision.
        # A GitHub token is required while the flake repo is private, and avoids
        # anonymous API rate limits once it is public.
        token="''${GITHUB_TOKEN:-''${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
        if [[ -n "$token" ]]; then
          export NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"extra-access-tokens = github.com=$token"
        fi
        nix run --refresh ${lib.escapeShellArg remoteFlake} -- "''${args[@]}"
      fi

      if [[ "$push" == true && "$dry_run" == false ]]; then
        profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
        ${lib.getExe pkgs.cachix} push thehuman "$(readlink -f "$profile")"
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
      stylua --no-editorconfig nix/modules/neovim shared/nvim mise/config/nvim
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
      stylua --no-editorconfig --check nix/modules/neovim shared/nvim mise/config/nvim
      if [[ -d .github/workflows ]]; then
        find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -exec actionlint {} +
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
      hunk
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
