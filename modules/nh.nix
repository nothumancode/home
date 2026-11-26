{
  config,
  ...
}:

{
  programs.nh = {
    enable = true;
    homeFlake = "${config.xdg.configHome}/home-manager";

    # Daily `nh clean user` (a missed run catches up at the next start: the timer is
    # Persistent). Rollback stays possible to the newest 10 generations whatever their
    # age, and to anything from the last 3 days; every direnv project keeps a root, so
    # project shells are never collected.
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep 10 --keep-since 3d --keep-one";
    };
  };
}
