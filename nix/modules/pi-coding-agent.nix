{
  config,
  lib,
  pkgs,
  ...
}:

let
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

    settings = builtins.fromJSON (builtins.readFile ../../shared/pi/settings.json);
    models = builtins.fromJSON (builtins.readFile ../../shared/pi/models.json);
  };

  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    mcpServers = (builtins.fromJSON (builtins.readFile ../../shared/pi/mcp.json)).mcpServers // {
      gateway = {
        url = "https://gateway.docker.com/mcp/gateways/sk/usergw-a58008f92e8bde6efe78a45a556242d466bf8147/mcp";
        type = "http";
        description = "Gateway for multiple MCP server tools.";
        oauth.scope = "openid offline_access";
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
      staticSettings = ../../shared/pi/open-tui.json;
      jqOperation = "$static * $dynamic";
    }
  );
}
