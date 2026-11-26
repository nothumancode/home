{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.doppler;
in
{
  options.doppler = {
    project = lib.mkOption {
      type = lib.types.str;
      default = "global";
      description = "Default Doppler project for bare `doppler` commands (DOPPLER_PROJECT).";
    };
    config = lib.mkOption {
      type = lib.types.str;
      default = "lf";
      description = "Default Doppler config for bare `doppler` commands (DOPPLER_CONFIG).";
    };
  };

  config = {
    # `withDopplerSecrets { name, project, config, program, secrets ? [ ] }`: a launcher
    # that runs `program` with the secrets of one Doppler config (all of them, or only
    # `secrets` when listed). Without Doppler auth it runs `program` without them, so a
    # tool's own stored login still works.
    _module.args.withDopplerSecrets =
      {
        name,
        project,
        config,
        program,
        secrets ? [ ],
      }:
      pkgs.writeShellApplication {
        inherit name;
        text = ''
          doppler=${lib.getExe pkgs.doppler}
          if [[ -z "''${DOPPLER_TOKEN:-}" && -z "$("$doppler" configure get token --plain 2>/dev/null)" ]]; then
            echo "${name}: no Doppler login; starting without ${project}/${config} secrets" >&2
            exec ${program} "$@"
          fi
          exec "$doppler" run \
            --project ${lib.escapeShellArg project} \
            --config ${lib.escapeShellArg config} \
            ${lib.concatMapStringsSep " " (secret: "--only-secrets ${lib.escapeShellArg secret}") secrets} \
            -- ${program} "$@"
        '';
      };

    home.sessionVariables = {
      DOPPLER_PROJECT = cfg.project;
      DOPPLER_CONFIG = cfg.config;
    };
  };
}
