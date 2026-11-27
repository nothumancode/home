{
  lib,
  config,
  pkgs,
  withDopplerSyncedFile,
  ...
}:

let
  # Where the Home Manager module puts Codex's files (it sets CODEX_HOME only for XDG).
  codexHome = config.home.sessionVariables.CODEX_HOME or "${config.home.homeDirectory}/.codex";

  # Codex's login (auth.json) follows you across machines via agents/codex CODEX_AUTH_JSON:
  # `doppler secrets get CODEX_AUTH_JSON -p agents -c codex --raw --plain | jq .codexAuthJson`.
  # The file is one login, not one per provider; Codex records refreshes in `last_refresh`
  # and refreshes under an flock on auth.lock.
  codexWrapper = withDopplerSyncedFile {
    name = "codex";
    project = "agents";
    config = "codex";
    program = lib.getExe pkgs.codex;
    path = "${codexHome}/auth.json";
    secret = "CODEX_AUTH_JSON";
    envelopeKey = "codexAuthJson";
    entries = false;
    timeKey = "last_refresh";
    lock.flock = "${codexHome}/auth.lock";
    removeOnExit = false;
  };
in
{
  programs.codex = {
    enable = true;
    mutableSettings = true;
    # The module reads Codex's version from the package (config.toml from 0.2.0 on).
    package = codexWrapper.overrideAttrs { inherit (pkgs.codex) version; };
    settings = {
      model = "gpt-6.2-astra";
      model_reasoning_effort = "medium";
      service_tier = "default";
      # The sync reads and writes auth.json; a keyring login would bypass it.
      cli_auth_credentials_store = "file";
    };
  };
}
