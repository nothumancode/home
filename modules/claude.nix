{ ... }:

{
  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    settings = {
      attribution = false;
      model = "claude-opus-5-5";
      modelSettings = {
        "claude-opus-5-5" = {
          effortLevel = "high";
        };
        "claude-fable-5-2" = {
          effortLevel = "high";
        };
      };
      permissions = { defaultMode = "auto"; };
      statusLine = {
        command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
        padding = 0;
        type = "command";
      };
      theme = "dark";
    };
  };
}
