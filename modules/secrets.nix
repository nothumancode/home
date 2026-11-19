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
  hasSpec = builtins.pathExists ../secretspec.toml;
  # File-backed providers resolve paths (including secrets.age) next to the manifest.
  specFile = "${config.xdg.configHome}/home-manager/secretspec.toml";

  keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
  sops = lib.getExe pkgs.sops;

  # Use the existing SecretSpec provider until a sops environment is committed.
  # Do not contact Doppler on machines that use sops.
  loadValues =
    current:
    if hasEnv then
      ''
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
      ''
    else
      ''
        local exports
        [[ -r ${lib.escapeShellArg specFile} ]] || return 0
        [[ -n ''${DOPPLER_TOKEN:-} || -n ''${SECRETSPEC_PROVIDER:-} ||
           -r "''${XDG_CONFIG_HOME:-$HOME/.config}/secretspec/config.toml" ]] || return 0
        exports=$(${lib.getExe pkgs.secretspec} export --file ${lib.escapeShellArg specFile} --format shell </dev/null 2>/dev/null) || return 0
        eval "$exports"
      '';

  # Disable tracing locally before handling values in either shell.
  loadEnv =
    { quiet, current }:
    lib.optionalString (hasEnv || hasSpec) ''
      __hm_load_secrets() {
        ${quiet}
        ${loadValues current}
      }
      __hm_load_secrets
      unset -f __hm_load_secrets
    '';
in
{
  home.packages = [
    pkgs.sops
    pkgs.age
    pkgs.doppler
    (pkgs.callPackage ../scripts/secrets.nix { })
  ];

  # A separately installed devenv also ships bin/secretspec. Expose the pinned
  # CLI on PATH without claiming that file in the user's Nix profile.
  home.sessionPath = [ "${lib.getBin pkgs.secretspec}/bin" ];

  # sops looks in a different place on macOS unless this is set.
  home.sessionVariables.SOPS_AGE_KEY_FILE = keyFile;

  programs.bash.initExtra = loadEnv {
    quiet = "local -; set +x";
    current = "\${!name:-}";
  };

  programs.zsh.initContent = loadEnv {
    quiet = "setopt local_options no_xtrace";
    current = "\${(P)name:-}";
  };

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

  warnings = lib.optional (!hasEnv && !hasSpec) ''
    Neither secrets/env.yaml nor secretspec.toml exists, so no secrets are loaded into the shell.
    Run `secrets init` once, then `secrets set NAME` for each variable.
  '';
}
