{
  programs = {
    direnv = {
      enable = true;
      enableGitIntegration = true;
      nix-direnv.enable = true;
      config.global = {
        hide_env_diff = true;
        warn_timeout = "30s";
      };
    };

    # Use direnv + nix-direnv for in-place shell activation rather than
    # devenv prompt hook, which spawns nested subshells on cd.
    devenv = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
    };
  };
}
