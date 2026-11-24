{ ... }:
{
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    enableGitIntegration = true;
    nix-direnv.enable = true;
  };
}
