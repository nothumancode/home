{
  lib,
  pkgs,
  kbtd,
  ...
}:

{
  # Command-line tools that people and coding agents both rely on. Editor
  # tooling (language servers, formatters) lives in the Neovim wrapper instead.
  home.packages =
    with pkgs;
    [
      # Search and structured data
      ripgrep
      fd
      jq
      yq-go
      ast-grep
      tree
      file

      # Shell and build
      shellcheck
      shfmt
      gnumake
      hyperfine

      # Network and archives
      curl
      wget
      unzip
      zip

      # Git and GitHub
      gh
      lazygit

      # Nix
      cachix
      nixfmt
      nixfmt-tree

      # Runtimes
      nodejs_24
      python313
      uv

      # Markdown Kanban board
      kbtd.packages.${pkgs.stdenv.hostPlatform.system}.default

      # Secret management (the pinned SecretSpec CLI is on the session PATH)
      age
      doppler

      # System
      btop
    ]
    # macOS ships BSD tools with different flags. The GNU versions make
    # commands such as `sed -i` and `grep -P` behave the same on every platform.
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      coreutils
      findutils
      diffutils
      gnugrep
      gnused
      gnutar
      gawk
    ];
}
