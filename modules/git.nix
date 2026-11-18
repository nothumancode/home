{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Tomas Roda";
        email = "rodat@leadforensics.com";
      };

      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
}
