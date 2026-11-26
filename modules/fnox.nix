{ config, ... }:

let
  # Credentials stay out of the shell hook: `env = "exec"` secrets reach only
  # `fnox exec -- <command>` and `fnox get`, never every interactive shell (and with
  # it every coding agent started from one).
  credential = name: {
    provider = "doppler";
    value = name;
    env = "exec";
  };
in
{
  programs.fnox = {
    enable = true;
    settings = {
      default_provider = "doppler";
      if_missing = "warn";
      daemon.enabled = true;
      providers.doppler = {
        type = "doppler";
        inherit (config.doppler) project config;
      };
      secrets = {
        CACHIX_AUTH_TOKEN = credential "CACHIX_AUTH_TOKEN";
        MODAL_TOKEN_ID = credential "MODAL_TOKEN_ID";
        MODAL_TOKEN_SECRET = credential "MODAL_TOKEN_SECRET";
        # A host name, not a credential, exported for interactive use; GitHub login setup
        # reads GH_ENTERPRISE_HOST instead, and only from the switch environment.
        GITHUB_ENTERPRISE_HOST = {
          provider = "doppler";
          value = "GITHUB_ENTERPRISE_HOST";
        };
      };
    };
  };
}
