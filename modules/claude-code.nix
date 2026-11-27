{
  lib,
  pkgs,
  dopplerLib,
  ...
}:

let
  claudeCodeWrapped = dopplerLib.withSecrets {
    name = "claude";
    project = "agents";
    config = "claude-code";
    program = lib.getExe pkgs.claude-code;
  };
in
{
  programs.claude-code = {
    enable = true;
    package = claudeCodeWrapped;
    enableMcpIntegration = true;
    mutableSettings = true;
    settings = {
      env = {
        CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS = "100000";
      };
      permissions = {
        defaultMode = "auto";
      };
      defaultModel = "claude-opus-5-5";
      modelSettings = {
        "claude-fable-5-2" = {
          effortLevel = "high";
        };
        "claude-opus-5-5" = {
          effortLevel = "xhigh";
        };
      };
      promptCacheTtl = "1h";
      subagentPromptCacheTtl = "1h";
      enableWorkflows = true;
      advisor = "fable";
      autoCompactEnabled = true;
      autoCompactWindow = 400000;
      idleCompaction = true;
      awaySummaryEnabled = true;
      autoMemoryEnabled = true;
      theme = "dark";
      tui = "fullscreen";
      outputStyle = "Concise";
      effortLevel = "high";
      spinnerTipsEnabled = false;
      showThinkingSummaries = true;
      showTurnDuration = true;
      terminalProgressBarEnabled = true;
      copyOnSelect = true;
      autoScrollEnabled = true;
      bashEditDiffEnabled = true;
      skipDangerousModePermissionPrompt = true;
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      channelsEnabled = true;
      extraKnownMarketplaces = {
        "claude-mods" = {
          source = {
            source = "git";
            url = "https://github.com/thehumanworks/claude-mods.git";
          };
        };
      };
      enabledPlugins = {
        "async-compaction@claude-mods" = true;
        "efficiency@claude-mods" = true;
        "handoff@claude-mods" = true;
        "output-shaper@claude-mods" = true;
        "turn-stats@claude-mods" = true;
      };
    };
  };
}
