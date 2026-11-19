{
  config,
  lib,
  pkgs,
  ...
}:

{
  xdg.configFile."nix/hm-cachix.conf".source = ../config/nix/cachix.conf;

  # nix.conf can contain private access-tokens. Keep it in place; only the
  # public include is managed in the store. !include is harmless after removal.
  home.activation.enableCachix = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    nixConf=${lib.escapeShellArg "${config.xdg.configHome}/nix/nix.conf"}
    cachixInclude='!include hm-cachix.conf'
    if ! grep -Fxq -- "$cachixInclude" "$nixConf" 2>/dev/null; then
      if [[ -L $nixConf || ( -e $nixConf && ! -w $nixConf ) ]]; then
        warnEcho "To enable Cachix, add '$cachixInclude' to $nixConf."
      else
        run ${pkgs.runtimeShell} -c 'umask 077; printf "\n%s\n" "$1" >> "$2"' _ "$cachixInclude" "$nixConf"
      fi
    fi
  '';
}
