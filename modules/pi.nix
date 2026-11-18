{ config, lib, ... }:

let
  pi = config.programs.pi-coding-agent;
  mcpFile = config.xdg.configFile."mcp/mcp.json" or null;
in
{
  programs.pi-coding-agent = {
    enable = true;
    settings = {
      theme = "vercel-dark";
      compaction = {
        enabled = true;
      };
      defaultModel = "gpt-6.2-astra";
      defaultThinkingLevel = "high";
      defaultProvider = "openai";
      enabledModels = [
        "gpt-6.2-sol"
        "gpt-6.2-astra"
        "gpt-6.1-terra"
      ];
      packages = [
        "npm:pi-open-tui"
        "npm:@nothumanwork/pi-tps"
        "npm:@nothumanwork/pi-advisor"
        "npm:@nothumanwork/pi-usage"
        "npm:@nothumanwork/pi-fast"
        "npm:@nothumanwork/pi-background-compaction"
      ];
      backgroundCompaction = {
        enabled = true;
        model = "openai/gpt-6.1-terra";
      };
    };

    mutableSettings = true;
  };

  home.file."${pi.configDir}/themes/vercel-dark.json".text = lib.toJSON (import ../themes/pi.nix);

  # Pi has no enableMcpIntegration option; reuse the mcpServers file from programs.mcp.
  home.file."${pi.configDir}/mcp.json" = lib.mkIf (pi.enable && mcpFile != null) {
    inherit (mcpFile) source;
  };

  home.file.".pi/agent/models.json".text = lib.toJSON {
    "$schema" = "https://pi.dev/schemas/models.schema.json";
    providers.openai.modelOverrides = {
      "gpt-6.2-astra".contextWindow = 400000;
      "gpt-6.2-sol".contextWindow = 400000;
    };
  };

  home.file.".pi/agent/open-tui.json".text = lib.toJSON {
    enabled = true;
    header = true;
    inlineFooter = false;
    copyButtons = true;
    settingsLanguage = "en";
    cursorStyle = "block";
    icons.mode = "ascii";
    footerSegments = {
      cwd = true;
      hostname = false;
      sessionName = false;
      gitBranch = true;
      gitStatus = true;
      gitCommit = false;
      runtime = true;
      context = true;
      contextBar = true;
      tokens = true;
      cost = true;
      liveTps = true;
      extensionSegments = true;
      extensionStatuses = true;
      capitalizeProviderName = true;
      nerdIconSpacing = false;
    };
    telemetry = {
      enabled = true;
      tps = true;
      ttft = true;
      duration = true;
      tokens = true;
      stalls = true;
      cost = true;
    };
    thinkingPeek.lines = 1;
    toolView = {
      mode = "native";
      extensionTools = false;
      exclude = [ ];
    };
  };
}
