{
  lib,
  pkgs,
  ...
}:

let
  version = "2.27.0";

  sources = {
    x86_64-linux = {
      asset = "dagu_${version}_linux_amd64.tar.gz";
      hash = "sha256-qQRXaMl3fQuThYVpbgSRvAzkb76wQZmJs0/eY6DMb4U=";
    };
    aarch64-linux = {
      asset = "dagu_${version}_linux_arm64.tar.gz";
      hash = "sha256-vmaCMmZTgzDkQDUmWDBMEmEEeo5YuDprZsCYqGYp0to=";
    };
    aarch64-darwin = {
      asset = "dagu_${version}_darwin_arm64.tar.gz";
      hash = "sha256-2Rn19v2NPr+11bhb1wO0U/c+3alnFN+9O164/RtV7NI=";
    };
  };

  inherit (pkgs.stdenv.hostPlatform) system;
  source = sources.${system} or (throw "dagu: unsupported system ${system}");

  dagu = pkgs.stdenvNoCC.mkDerivation {
    pname = "dagu";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/dagucloud/dagu/releases/download/v${version}/${source.asset}";
      inherit (source) hash;
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 dagu "$out/bin/dagu"
      runHook postInstall
    '';

    meta = {
      description = "Compact, portable, and language-agnostic workflow engine";
      homepage = "https://github.com/dagucloud/dagu";
      license = lib.licenses.gpl3Only;
      mainProgram = "dagu";
      platforms = builtins.attrNames sources;
    };
  };
in
{
  home.packages = [ dagu ];
}
