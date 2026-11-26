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
      default = "vault";
      description = "Doppler project that holds personal secrets.";
    };
    config = lib.mkOption {
      type = lib.types.str;
      default = "prd";
      description = "Doppler config (environment) within the project.";
    };
  };

  config = {
    # `withDopplerSecrets { name, secrets, program }`: a launcher that hands `program`
    # only the listed secrets, so it never sees the rest of the project.
    _module.args.withDopplerSecrets =
      {
        name,
        secrets,
        program,
      }:
      pkgs.writeShellApplication {
        inherit name;
        text = ''
          exec ${lib.getExe pkgs.doppler} run \
            --project ${lib.escapeShellArg cfg.project} \
            --config ${lib.escapeShellArg cfg.config} \
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
