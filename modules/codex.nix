{
  programs.codex = {
    enable = true;
    mutableSettings = true;
    settings = {
      model = "gpt-6.2-astra";
      model_reasoning_effort = "medium";
      service_tier = "default";
    };
  };
}
