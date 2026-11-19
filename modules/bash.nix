{ pkgs, ... }:

let
  secretspecFile = ../secretspec.toml;
in
{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    profileExtra = ''
      	if [[ -f "$HOME/.bashrc" ]]; then
      	  source "$HOME/.bashrc"
      	fi
    '';

    initExtra = ''
      eval "$(${pkgs.secretspec}/bin/secretspec export -f ${secretspecFile} --format shell)"
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
