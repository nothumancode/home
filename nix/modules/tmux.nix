{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    customPaneNavigationAndResize = true;
    escapeTime = 0;
    focusEvents = true;
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";

    extraConfig = builtins.readFile ../../shared/tmux/home.conf;
  };
}
