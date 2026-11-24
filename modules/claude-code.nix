{
  programs.claude-code = {
    enable = true;
    mutableSettings = true;
    settings = {
      theme = "dark";
      tui = "fullscreen";
      outputStyle = "Concise";
      effortLevel = "high";
      spinnerTipsEnabled = false;
      showThinkingSummaries = true;
      showTurnDuration = true;
      terminalProgressBarEnabled = true;
      copyOnSelect = true;
      autoScrollEnabled = true;
      autoCompactEnabled = true;
      idleCompaction = true;
      bashEditDiffEnabled = true;
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
    };
  };
}
