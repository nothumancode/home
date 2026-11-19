{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = import ../themes/palette.nix;
in
{
  # Aliases, variables and tool integrations below apply to every enabled shell.
  home.shellAliases = {
    ll = "ls -alF";
    gs = "git status";
    gp = "git pull";
    hms = "home-manager switch -b backup --flake ${config.xdg.configHome}/home-manager";
  };

  # `uv tool install` and similar per-user installers put programs here.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.bash = {
    enable = true;
    enableCompletion = true;
    historySize = 100000;
    historyFileSize = 100000;
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];
  };

  # Zsh is the login shell on macOS. Bash stays installed there for scripts and agents.
  programs.zsh = {
    enable = lib.mkDefault pkgs.stdenv.hostPlatform.isDarwin;
    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreSpace = true;
    };
  };

  # Plain text prompt: no icon font is needed in any terminal.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$username$hostname$directory$git_branch$git_state$git_status$nix_shell$cmd_duration$line_break$jobs$character";
      palette = "vercel";
      palettes.vercel = {
        inherit (c)
          text
          muted
          quiet
          blue
          green
          amber
          red
          ;
      };
      username.format = "[$user]($style)@";
      username.style_user = "muted";
      hostname.format = "[$hostname]($style) ";
      hostname.style = "muted";
      directory.style = "bold text";
      directory.truncate_to_repo = false;
      git_branch.format = "[$branch]($style) ";
      git_branch.style = "muted";
      git_state.style = "amber";
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "amber";
        deleted = "x";
        renamed = "r";
        ahead = "^";
        behind = "v";
        diverged = "^v";
      };
      nix_shell.format = "[nix]($style) ";
      nix_shell.style = "blue";
      nix_shell.heuristic = true;
      cmd_duration.format = "[$duration]($style) ";
      cmd_duration.style = "quiet";
      jobs.symbol = "+";
      jobs.style = "blue";
      character.success_symbol = "[>](green)";
      character.error_symbol = "[>](red)";
    };
  };

  # Ctrl-R searches history, Ctrl-T inserts a file path, Alt-C changes directory.
  programs.fzf = {
    enable = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
  };

  # `z <part of a path>` jumps to a directory used before.
  programs.zoxide.enable = true;

  programs.bat = {
    enable = true;
    config.theme = "ansi";
  };

  # A project's .envrc can use `use flake` (cached by nix-direnv).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };
}
