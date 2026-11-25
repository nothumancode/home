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
          secrets.CACHIX_AUTH_TOKEN = {
            provider = "doppler";
            value = "CACHIX_AUTH_TOKEN";
          };
        };
  };
}
