{
  # github:thehumanworks/doppler-nix: the `doppler` CLI, `doppler-auth-sync` and
  # `doppler-env` on PATH, and the module argument `dopplerLib` the launchers in the other
  # modules are made with (`withSecrets`, `withSyncedFile`).
  programs.doppler = {
    enable = true;

    # Only the defaults for bare `doppler` commands; every launcher names its own config.
    project = "global";
    config = "lf";

    # `use doppler PROJECT CONFIG` in a project's .envrc loads that config's secrets.
    direnv.enable = true;
  };
}
