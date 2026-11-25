{
  programs.codex = {
    enable = true;
    mutableSettings = true;
    settings = builtins.fromTOML (builtins.readFile ../../shared/codex/config.toml);
  };
}
