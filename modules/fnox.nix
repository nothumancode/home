{
  programs.fnox = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      default_provider = "doppler";
      if_missing = "warn";
      daemon.enabled = true;
      providers.doppler = {
        type = "doppler";
        project = "vault";
        config = "prd";
      };
      secrets = {
        AI_GATEWAY_API_KEY = {
          provider = "doppler";
          value = "AI_GATEWAY_API_KEY";
        };
        CACHIX_AUTH_TOKEN = {
          provider = "doppler";
          value = "CACHIX_AUTH_TOKEN";
        };
      };
    };
  };
}
