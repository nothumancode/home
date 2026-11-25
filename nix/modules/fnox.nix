{ lib, ... }:
{
  programs.fnox = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings =
      lib.recursiveUpdate
        (
          (builtins.fromTOML (builtins.readFile ../../shared/fnox/config.toml))
          // (builtins.fromTOML (builtins.readFile ../../shared/fnox/enterprise.toml))
        )
        {
          secrets =
            lib.genAttrs
              [
                "CACHIX_AUTH_TOKEN"
                "CACHIX_AGENT_TOKEN"
                "CACHIX_ACTIVATE_TOKEN"
                "MODAL_TOKEN_ID"
                "MODAL_TOKEN_SECRET"
              ]
              (name: {
                provider = "doppler";
                value = name;
              });
        };
  };
}
