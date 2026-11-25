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
        CACHIX_AUTH_TOKEN = {
          provider = "doppler";
          value = "CACHIX_AUTH_TOKEN";
        };
        CACHIX_AGENT_TOKEN = {
          provider = "doppler";
          value = "CACHIX_AGENT_TOKEN";
        };
        CACHIX_ACTIVATE_TOKEN = {
          provider = "doppler";
          value = "CACHIX_ACTIVATE_TOKEN";
        };
        MODAL_TOKEN_ID = {
          provider = "doppler";
          value = "MODAL_TOKEN_ID";
        };
        MODAL_TOKEN_SECRET = {
          provider = "doppler";
          value = "MODAL_TOKEN_SECRET";
        };
        GITHUB_ENTERPRISE_HOST = {
          provider = "doppler";
          value = "GITHUB_ENTERPRISE_HOST";
        };
      };
    };
  };
}
