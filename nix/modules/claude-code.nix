{
  programs.claude-code = {
    enable = true;
    mutableSettings = true;
    settings = builtins.fromJSON (builtins.readFile ../../shared/claude/settings.json);
  };
}
