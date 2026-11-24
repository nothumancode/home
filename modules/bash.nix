{ lib, pkgs, ... }:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = lib.mkAfter ''
      export DOPPLER_PROJECT=vault
      export DOPPLER_CONFIG=prd

      # fnox activation
      eval "$(fnox activate bash)"

      if [[ -t 0 && -t 1 && $TERM != dumb ]]; then
        PS1='\[\e[1m\]▲\[\e[0m\] \[\e[94m\]\w\[\e[0m\]\n\[\e[35m\]❯\[\e[0m\] '

        if [[ -v BLE_VERSION ]] || source "${pkgs.blesh}/share/blesh/ble.sh" --attach=prompt; then
          ble-bind -f up   'history-search-backward immediate-accept:point=end:hide-status'
          ble-bind -f down 'history-search-forward immediate-accept:point=end:hide-status'
        fi
      fi
    '';
  };
}
