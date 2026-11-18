{ lib, pkgs, ... }:

let
  dotenvx = lib.getExe pkgs.dotenvx;

  # Bash exports: variable name -> encrypted dotenvx file. Files can be reused.
  shellTokens = {
    CACHIX_AUTH_TOKEN = ../secrets/.env.cachix;
    EXA_API_KEY = ../secrets/.env.exa;
  };

  loadShellToken =
    name: file:
    assert lib.assertMsg (
      builtins.match "[a-zA-Z_][a-zA-Z0-9_]*" name != null
    ) "Invalid dotenvx shell variable name: ${name}";
    "_hm_load_dotenvx_token ${name} ${lib.escapeShellArg "${file}"}";
in
{
  home.packages = [ pkgs.dotenvx ];

  programs.bash.initExtra = ''
    _hm_load_dotenvx_token() {
      local -  # Restore shell options on return; never trace decrypted values.
      set +x
      [[ -z ''${!1:-} ]] || return 0  # Keep a nonempty value already in the shell.

      local value keys="''${XDG_CONFIG_HOME:-$HOME/.config}/dotenvx/.env.keys"
      local -a key_args=()
      if [[ -r "$keys" ]]; then key_args=(-fk "$keys"); fi

      # A global lookup shouldn't pick up dotenvx configuration from the current project.
      if value="$(cd / && ${dotenvx} get "$1" --quiet --strict -o \
          -f "$2" "''${key_args[@]}")" && [[ -n "$value" ]]; then
        declare -gx "$1=$value"
      fi
    }

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList loadShellToken shellTokens)}
    unset -f _hm_load_dotenvx_token
  '';
}
