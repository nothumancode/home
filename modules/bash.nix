{ ... }:
{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    profileExtra = ''
      	if [[ -f "$HOME/.bashrc" ]]; then
      	  source "$HOME/.bashrc"
      	fi
    '';

    shellAliases = {
      ll = "ls -alF";
      gs = "git status";
      gp = "git pull";
      vim = "nvim";
      vi = "nvim";
      hms = "home-manager switch -b backup --flake \"$HOME/.config/home-manager#rodat\"";
    };
  };
}
