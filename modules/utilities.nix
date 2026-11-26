{
  config,
  lib,
  pkgs,
  remoteFlake,
  withDopplerSecrets,
  ...
}:

let
  localFlakeDir = "${config.xdg.configHome}/home-manager";

  # Commands that need credentials get their own Doppler config.
  cachixWithToken = withDopplerSecrets {
    name = "cachix-with-token";
    project = "tools";
    config = "nix";
    program = lib.getExe pkgs.cachix;
  };
  modalWithToken = withDopplerSecrets {
    name = "modal";
    project = "tools";
    config = "modal";
    program = lib.getExe pkgs.modal;
  };

  # Runs a command in the local checkout, or explains that there is none.
  inCheckout = name: ''
    repo=${lib.escapeShellArg localFlakeDir}
    if [[ ! -f "$repo/flake.nix" ]]; then
      echo "${name}: no local checkout found at $repo" >&2
      exit 1
    fi
    cd "$repo"
  '';

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
        # rom in nh 4.5 warns on Determinate Nix activity 10113. Use native progress by default.
        NH_ROM="''${NH_ROM:-0}" ${lib.getExe config.programs.nh.package} home switch -b backup ${lib.escapeShellArg localFlakeDir} "''${args[@]}"
      else
        # No checkout: run the flake's own switch app at the latest remote revision.
        # The repository is public; a token, when there is one, only avoids anonymous
        # GitHub API rate limits.
        token="''${GITHUB_TOKEN:-''${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}}"
        if [[ -n "$token" ]]; then
          export NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"extra-access-tokens = github.com=$token"
        fi
        nix run --refresh ${lib.escapeShellArg remoteFlake} -- "''${args[@]}"
      fi

      if [[ "$push" == true && "$dry_run" == false ]]; then
        profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
        ${lib.getExe cachixWithToken} push thehuman "$(readlink -f "$profile")"
      fi
    '';
  };

  # Both wrap the flake's own formatter (flake.nix `treefmt`), so the rules live once.
  hmFmt = pkgs.writeShellApplication {
    name = "hm-fmt";
    text = ''
      ${inCheckout "hm-fmt"}
      nix fmt
    '';
  };

  hmCheck = pkgs.writeShellApplication {
    name = "hm-check";
    runtimeInputs = [
      pkgs.actionlint
      pkgs.statix
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

      ${inCheckout "hm-check"}

      nix fmt -- --ci
      statix check .
      actionlint .github/workflows/*.yml

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
      git = true;
      icons = "never";
      extraOptions = [ "--group-directories-first" ];
    };

    fd.enable = true;

    fzf = {
      enable = true;
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

    zoxide.enable = true;
  };

  # Daily tools only. Project toolchains (Go, gcc/make/pkg-config, pnpm, bun,
  # TypeScript, pinned Pythons) come from each project's own environment; anything
  # else runs once with `, <command>` (nix-index-database comma).
  home.packages = with pkgs; [
    hmCheck
    hmFmt
    hmSwitch

    # Runtimes for scripts and agents (npx-launched MCP servers, ad-hoc Python)
    nodejs_24
    python3

    # Code intelligence, structured data, and task runners
    ast-grep
    hunk
    just
    lefthook
    poppler-utils # pdftoppm/pdftotext for agent document skills
    sd
    sqlite
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

    # Modal CLI with its token from Doppler
    modalWithToken

    # Terminal, network, archive, and diagnostic utilities
    btop
    curl
    dnsutils
    file
    gnutar
    lsof
    openssh
    rsync
    tree
    unzip
    wget
    xz
    zip
    zstd

    # Linux-only (every target is Linux)
    bubblewrap
    iproute2
    psmisc
  ];
}
