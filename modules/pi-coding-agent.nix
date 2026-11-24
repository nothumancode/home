{ ... }:
{
  programs.pi-coding-agent = {
    enable = true;
    mutableSettings = true;
    settings = {
      defaultProvider = "openai";
      defaultModel = "gpt-6.2-sol";
      enabledModels = [
        "openai/gpt-6.2-sol"
        "openai/gpt-6.2-astra"
        "openai/gpt-6.1-terra"
      ];
      modelThinkingLevels = {
        "openai/gpt-6.2-sol" = "max";
      };
      enableInstallTelemetry = false;
      quietStartup = true;
      collapseChangelog = true;
      showCacheMissNotices = true;
      transport = "websocket-cached";
      defaultProjectTrust = "always";
      codemode = {
        mode = "only";
      };
      terminal.showTerminalProgress = true;
      advisorModel = "openai/gpt-6.2-astra";
      packages = [
        "npm:pi-open-tui"
        "npm:@nothumanwork/pi-loggly"
        "npm:@nothumanwork/pi-fast"
        "npm:@nothumanwork/pi-advisor"
        "npm:@nothumanwork/pi-background-compaction"
        "npm:@nothumanwork/pi-idle-compaction"
      ];
      backgroundCompaction = {
        enabled = true;
        model = "openai/gpt-6.1-terra";
      };
      idleCompaction = {
        enabled = true;
        tokenThreshold = 100000;
        idleMinutes = 5;
      };
      fast = {
        ultrafastModels = [ "gpt-6.2-sol" ];
      };
    };
  };

  home.file.".pi/agent/models.json".text = builtins.toJSON {
    "$schema" = "https://pi.dev/schemas/models.schema.json";
    providers.openai.modelOverrides = {
      "gpt-6.2-astra".contextWindow = 400000;
      "gpt-6.2-sol".contextWindow = 400000;
    };
  };

  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    mcpServers = {
      gateway = {
        url = "https://gateway.docker.com/mcp/gateways/sk/usergw-a58008f92e8bde6efe78a45a556242d466bf8147/mcp";
        type = "http";
        description = "Gateway for multiple MCP server tools.";
        oauth.scope = "openid offline_access";
      };
    };
  };

}
