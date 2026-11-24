{ config, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Tomas Roda";
        email = "rodat.dev@proton.me";
        useConfigOnly = true;
      };

      init.defaultBranch = "main";

      push = {
        default = "simple";
        autoSetupRemote = true;
      };

      diff.algorithm = "histogram";

      merge = {
        conflictStyle = "zdiff3";
        tool = "nvimdiff";
      };

      rerere = {
        enabled = true;
        autoupdate = true;
      };
    };

    # Populated at activation time by modules/gh.nix so the
    # enterprise host and work identity stay out of the Nix store.
    includes = [
      { path = "${config.xdg.configHome}/git/enterprise.gitconfig"; }
    ];
  };
}
