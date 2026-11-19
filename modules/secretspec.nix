{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Use the checkout, not an individual store copy: providers can reference
  # secrets.age next to the manifest. Never resolve a value during a Nix build.
  manifest = lib.escapeShellArg "${config.xdg.configHome}/home-manager/secretspec.toml";
  loadSecrets = ''
    __hm_load_secretspec() {
      [[ -r ${manifest} ]] || return 0
      local __hm_flags=$- __hm_exports=""
      set +vx  # Neither verbose input nor xtrace should log the exports.
      if __hm_exports=$(${lib.getExe pkgs.secretspec} export --file ${manifest} --profile default --format shell </dev/null 2>/dev/null); then
        eval "$__hm_exports"
      fi
      [[ $__hm_flags != *v* ]] || set -v
      [[ $__hm_flags != *x* ]] || set -x
    }
    __hm_load_secretspec
    unset -f __hm_load_secretspec
  '';
in
{
  # Leave the machine's SecretSpec provider aliases alone. A standalone
  # devenv also ships bin/secretspec; don't claim that file in the Nix profile.
  home.sessionPath = [ "${lib.getBin pkgs.secretspec}/bin" ];

  programs.bash.initExtra = loadSecrets;
  programs.zsh.initContent = loadSecrets;
}
