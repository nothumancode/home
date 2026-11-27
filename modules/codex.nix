{
  lib,
  pkgs,
  dopplerLib,
  ...
}:

let
  # Codex's login (auth.json) follows you across machines via agents/codex CODEX_AUTH_JSON
  # (`doppler-auth-sync --help`, preset codex). The file stays on disk: Codex's app-server
  # and IDE extensions read it without this launcher.
  codexWrapper = dopplerLib.withSyncedFile {
    name = "codex";
    preset = "codex";
    program = lib.getExe pkgs.codex;
  };
in
{
  programs.codex = {
    enable = true;
    # The module reads Codex's version from the package (config.toml from 0.2.0 on).
    package = codexWrapper.overrideAttrs { inherit (pkgs.codex) version; };
    # Codex writes trust and its own settings to config.toml; keep it writable.
    mutableSettings = true;
    settings = {
      model = "gpt-6.2-astra";
      model_reasoning_effort = "medium";
      service_tier = "default";
      # The sync reads and writes auth.json; a keyring login would bypass it.
      cli_auth_credentials_store = "file";
    };
  };
}
