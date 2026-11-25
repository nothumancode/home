{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = [ pkgs.git-absorb ];

  programs = {
    git = {
      enable = true;
      lfs.enable = true;

      ignores = lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile ../../shared/git/ignore));
      # Populated at activation time by modules/gh.nix so the
      # enterprise host and work identity stay out of the Nix store.
      includes = [
        { path = ../../shared/git/home.gitconfig; }
        { path = "${config.xdg.configHome}/git/enterprise.gitconfig"; }
      ];
    };

    # Syntax-highlighted TTY pager; non-TTY git diff stays clean unified output for AI agents.
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        hyperlinks = true;
      };
    };

    # Installed for difft and git difftool (git dft) alongside delta's TTY pager.
    difftastic.enable = true;

    lazygit = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      settings = builtins.fromJSON (builtins.readFile ../../shared/lazygit/config.yml);
    };
  };
}
