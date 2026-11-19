{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Each entry of this sops file becomes an environment variable in
  # interactive shells, and so in every program started from them.
  envFile = ../secrets/env.yaml;
  hasEnv = builtins.pathExists envFile;

  keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  sops = lib.getExe pkgs.sops;

  # The lines are read as data and never evaluated as shell code. A variable
  # that is already set keeps its value. Two things differ between Bash and
  # Zsh: `quiet` stops `set -x` from printing values, and `current` expands
  # the variable that $name names.
  loadEnv =
    { quiet, current }:
    ''
      __hm_load_secrets() {
        ${quiet}
        [[ -r ${lib.escapeShellArg keyFile} ]] || return 0
        local dotenv line name
        if ! dotenv=$(SOPS_AGE_KEY_FILE=${lib.escapeShellArg keyFile} ${sops} decrypt --output-type dotenv ${envFile} 2>/dev/null); then
          echo "secrets: cannot load the environment; run 'secrets status'" >&2
          return 0
        fi
        while IFS= read -r line; do
          name=''${line%%=*}
          case $name in
            "" | [0-9]* | *[!A-Za-z0-9_]*) continue ;;
          esac
          [[ -n ${current} ]] || export "$name=''${line#*=}"
        done <<<"$dotenv"
      }
      __hm_load_secrets
      unset -f __hm_load_secrets
    '';
in
{
  home.packages = [
    pkgs.sops
    pkgs.age
    (pkgs.callPackage ../scripts/secrets.nix { })
  ];

  # sops looks in a different place on macOS unless this is set.
  home.sessionVariables.SOPS_AGE_KEY_FILE = keyFile;

  programs.bash.initExtra = lib.mkIf hasEnv (loadEnv {
    quiet = "local -; set +x";
    current = "\${!name:-}";
  });

  programs.zsh.initContent = lib.mkIf hasEnv (loadEnv {
    quiet = "setopt local_options no_xtrace";
    current = "\${(P)name:-}";
  });

  home.activation.secretsKey = lib.mkIf hasEnv (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ ! -r ${lib.escapeShellArg keyFile} ]]; then
        warnEcho "The secrets key is not on this machine. Run: secrets unlock"
      fi
    ''
  );

  # In a project's .envrc, `use sops [FILE]` loads a sops file (default:
  # secrets.yaml) into the environment of that project only. jq quotes each
  # value for the shell, so a value cannot run as code.
  programs.direnv.stdlib = ''
    use_sops() {
      local file="''${1:-secrets.yaml}" exports
      watch_file "$file"
      exports=$(${sops} decrypt --output-type json "$file" | ${lib.getExe pkgs.jq} -r '
        to_entries[]
        | select(.key | test("^[A-Za-z_][A-Za-z0-9_]*$"))
        | select(.value | type | IN("string", "number", "boolean"))
        | "export \(.key)=\(.value | tostring | @sh)"') || return
      eval "$exports"
    }
  '';

  warnings = lib.optional (!hasEnv) ''
    secrets/env.yaml does not exist, so no secrets are loaded into the shell.
    Run `secrets init` once, then `secrets set NAME` for each variable.
  '';
}
