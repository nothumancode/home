{
  config,
  ...
}:

{
  programs.nh = {
    enable = true;
    homeFlake = "${config.xdg.configHome}/home-manager";

    # Weekly `nh clean user`: keeps the newest 10 generations and anything from the last
    # two weeks, so rollback targets stay while old closures become collectable.
    clean = {
      enable = true;
      extraArgs = "--keep 10 --keep-since 14d";
    };
  };
}
