{ pkgs, ... }:

let
  # `gh auth login` once per machine, then Git over HTTPS works with no further setup.
  ghCredential = {
    helper = [
      "" # Clear helpers inherited from the system configuration.
      "${pkgs.gh}/bin/gh auth git-credential"
    ];
  };
in
{
  programs.git = {
    enable = true;

    ignores = [
      ".direnv/"
      ".DS_Store"
      "result"
      "result-*"
    ];

    settings = {
      user = {
        name = "Tomas Roda";
        email = "rodat@leadforensics.com";
      };

      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
      fetch.prune = true;

      merge.conflictStyle = "zdiff3";
      diff.algorithm = "histogram";
      diff.colorMoved = "default";
      rerere.enabled = true;

      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      commit.verbose = true;

      credential."https://github.com" = ghCredential;
      credential."https://gist.github.com" = ghCredential;
    };
  };

  # Syntax-highlighted diffs in a terminal. Git does not start a pager for
  # programs that read its output, so scripts and agents are not affected.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "ansi";
    };
  };
}
