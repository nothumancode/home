{
  inputs,
  pkgs,
  dopplerLib,
  ...
}:
let
  inherit (pkgs) lib;
  jiradiffWrapper = dopplerLib.withSecrets {
    name = "jiradiff";
    program = lib.getExe inputs.jiradiff.packages.${pkgs.stdenv.hostPlatform.system}.default;
    project = "vault";
    config = "prd";
    secrets = [
      "ATLASSIAN_BASE_URL"
      "ATLASSIAN_API_USERNAME"
      "ATLASSIAN_API_TOKEN"
    ];
  };
in
{
  home.packages = [
    jiradiffWrapper
  ];
}
