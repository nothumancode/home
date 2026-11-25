{
  config,
  inputs,
  pkgs,
  ...
}:

let
  twg = pkgs.writeShellApplication {
    name = "twg";
    runtimeInputs = [
      pkgs.doppler
      inputs.twg.packages.${pkgs.stdenv.hostPlatform.system}.twg
    ];
    text = ''
      DOPPLER_PROJECT="vault" DOPPLER_CONFIG="prd" \
        doppler run \
          --only-secrets TWG_USER \
          --only-secrets TWG_SITE \
          --only-secrets TWG_TOKEN \
          -- \
          twg "$@"
    '';
  };
in
{
  programs.twg = {
    enable = true;
    package = twg;
    skillsDir = "${config.home.homeDirectory}/.agents/skills";
  };
}
