{ lib, pkgs, ... }:

let
  # Bash exports: variable name -> encrypted dotenvx file. Files can be reused.
  shellTokens = {
    CACHIX_AUTH_TOKEN = ../secrets/.env.cachix;
  };

  loadShellToken =
    name: file:
    assert lib.assertMsg (
      builtins.match "[a-zA-Z_][a-zA-Z0-9_]*" name != null
    ) "Invalid dotenvx shell variable name: ${name}";
    "_hm_load_dotenvx_token ${name} ${lib.escapeShellArg "${file}"}";

  # dotenvx needs the private keys, but the application and its children don't.
  withoutKeys = pkgs.writeShellScript "without-dotenv-keys" ''
    for key in "''${!DOTENV_PRIVATE_KEY@}"; do
      unset "$key"
    done
    exec "$@"
  '';

  mkRunner =
    appFiles:
    let
      # Only encrypted inputs belong here. --overload makes the last file win.
      files = [ ../secrets/.env.global ] ++ appFiles;
      fileArgs = lib.concatMapStringsSep " " (file: "-f ${file}") files;
    in
    pkgs.writeShellScriptBin "with-secrets" ''
      if (( $# == 0 )); then
        echo 'usage: with-secrets COMMAND [ARG...]' >&2
        exit 2
      fi
      exec ${lib.getExe pkgs.dotenvx} run --quiet --strict --overload \
        ${fileArgs} -- ${withoutKeys} "$@"
    '';

  wrapPackage =
    package: appFile:
    pkgs.symlinkJoin {
      pname = "${package.pname}-dotenv";
      inherit (package) version meta;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        launcher="$out/bin/${package.meta.mainProgram}"
        rm "$launcher"
        makeWrapper ${lib.getExe (mkRunner [ appFile ])} "$launcher" \
          --add-flags ${lib.getExe package}
      '';
    };
in
{
  home.packages = [
    pkgs.dotenvx
    (mkRunner [ ])
  ];

  programs.bash.initExtra = ''
    _hm_load_dotenvx_token() {
      local -  # Restore shell options on return; never trace decrypted values.
      set +x
      [[ -z ''${!1:-} ]] || return 0  # Keep a nonempty value already in the shell.

      local value keys="''${XDG_CONFIG_HOME:-$HOME/.config}/dotenvx/.env.keys"
      local -a key_args=()
      if [[ -r "$keys" ]]; then key_args=(-fk "$keys"); fi

      if value="$(${lib.getExe pkgs.dotenvx} get "$1" --quiet --strict -o \
          -f "$2" "''${key_args[@]}")" && [[ -n "$value" ]]; then
        declare -gx "$1=$value"
      fi
    }

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList loadShellToken shellTokens)}
    unset -f _hm_load_dotenvx_token
  '';

  programs.claude-code.package = wrapPackage pkgs.claude-code ../secrets/claude.env;
  programs.pi-coding-agent.package = wrapPackage pkgs.pi-coding-agent ../secrets/pi.env;
}
