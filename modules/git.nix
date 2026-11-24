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

      ignores = [
        ".DS_Store"
        "Thumbs.db"
        "*~"
        "*.swp"
        "*.swo"
        ".env.local"
        ".env.*.local"
        ".envrc.local"
      ];

      settings = {
        user = {
          name = "Tomas Roda";
          email = "rodat.dev@proton.me";
          useConfigOnly = true;
        };

        init.defaultBranch = "main";
        core.autocrlf = "input";
        commit.verbose = true;

        branch.sort = "-committerdate";
        tag.sort = "version:refname";

        fetch.prune = true;

        push = {
          default = "simple";
          autoSetupRemote = true;
        };

        rebase = {
          autoSquash = true;
          autoStash = true;
        };

        alias = {
          dft = "difftool";
        };

        diff = {
          algorithm = "histogram";
          colorMoved = "default";
          mnemonicPrefix = true;
          renames = true;
          tool = "difftastic";
        };

        difftool = {
          prompt = false;
          difftastic.cmd = ''${lib.getExe config.programs.difftastic.package} "$LOCAL" "$REMOTE"'';
        };

        pager.difftool = true;

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
      settings = {
        disableStartupPopups = true;
        notARepository = "quit";
        gui.nerdFontsVersion = "";
        git.pagers = [
          {
            colorArg = "always";
            pager = "delta --paging=never";
          }
        ];
      };
    };
  };
}
