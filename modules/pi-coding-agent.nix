{
  config,
  lib,
  pkgs,
  ...
}:

let
  jsonFormat = pkgs.formats.json { };

  piWrapper = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ ];
    text = ''
      DOPPLER_PROJECT="vault" DOPPLER_CONFIG="prd" \
        ${lib.getExe pkgs.doppler} run \
          --only-secrets LOGGLY_API_TOKEN \
          --only-secrets LOGGLY_SUBDOMAIN \
          --only-secrets EXA_API_KEY \
          --only-secrets AI_GATEWAY_API_KEY \
          -- \
          ${lib.getExe pkgs.pi-coding-agent} "$@"
    '';
  };
  openTuiDefaults = jsonFormat.generate "pi-open-tui.json" {
    enabled = true;
    header = true;
    inlineFooter = false;
    copyButtons = true;
    settingsLanguage = "en";
    cursorStyle = "block";
    icons.mode = "unicode";
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
      enabled = false;
      tps = true;
      ttft = true;
      duration = true;
      tokens = true;
      stalls = true;
      cost = true;
    };
    thinkingPeek.lines = 1;
    toolView = {
      mode = "compact";
      extensionTools = true;
      exclude = [ ];
    };
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    mutableSettings = true;
    package = piWrapper;

    extraPackages = with pkgs; [
      ast-grep
      bun
      fd
      git
      jq
      nodejs_24
      ripgrep
    ];

    settings = {
      defaultProvider = "openai";
      defaultModel = "gpt-6.2-sol";
      enabledModels = [
        "openai/gpt-6.2-sol"
        "openai/gpt-6.2-astra"
        "openai/gpt-6.1-terra"
        "vercel-ai-gateway/google/gemini-4-neon"
        "vercel-ai-gateway/google/gemini-4-carbon"
        "vercel-ai-gateway/google/gemini-4-hydrogen"
      ];
      modelThinkingLevels = {
        "openai/gpt-6.2-sol" = "max";
        "vercel-ai-gateway/google/gemini-4-neon" = "high";
      };
      enableInstallTelemetry = false;
      quietStartup = true;
      collapseChangelog = true;
      hideThinkingBlock = true;
      showCacheMissNotices = true;
      transport = "websocket";
      defaultProjectTrust = "always";
      codemode = {
        mode = "only";
      };
      terminal.showTerminalProgress = true;
      advisorModel = "openai/gpt-6.2-astra";
      packages = [
        "npm:pi-open-tui"
        "npm:@nothumanwork/pi-atlassian"
        "npm:@nothumanwork/pi-create-document"
        "npm:@nothumanwork/pi-worktree"
        "npm:@nothumanwork/pi-loggly"
        "npm:@nothumanwork/pi-fast"
        "npm:@nothumanwork/pi-remote"
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

    models = {
      "$schema" = "https://pi.dev/schemas/models.schema.json";
      providers = {
        openai.modelOverrides = {
          "gpt-6.2-astra".contextWindow = 400000;
          "gpt-6.2-sol".contextWindow = 400000;
        };
        vercel-ai-gateway.modelOverrides = {
          "google/gemini-4-neon".contextWindow = 600000;
        };
      };
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
      cns = {
        type = "stdio";
        command = "cns";
        args = [ "mcp" ];
        description = "Run commands across the network of connected devices via CNS";
      };
    };
  };

  # Keep open-tui.json writable for live TUI toggles while seeding defaults on new machines.
  home.activation.piOpenTuiSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    lib.hm.generators.mkImpureConfigMerger {
      inherit pkgs;
      format = "json";
      empty = "{}";
      mode = "600";
      path = "${config.programs.pi-coding-agent.configDir}/open-tui.json";
      staticSettings = openTuiDefaults;
      jqOperation = "$static * $dynamic";
    }
  );
}
