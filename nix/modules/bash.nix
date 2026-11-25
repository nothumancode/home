{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.bash = {
    enable = true;
    enableCompletion = true;

    historySize = 50000;
    historyFileSize = 200000;
    historyControl = [
      "ignoreboth"
      "erasedups"
    ];
    historyIgnore = [
      "ls"
      "ll"
      "la"
      "lt"
      "lla"
      "cd"
      "pwd"
      "exit"
      "clear"
      "fg"
      "bg"
    ];

    shellOptions = [
      "histappend"
      "checkwinsize"
      "extglob"
      "globstar"
      "checkjobs"
      "cdspell"
      "dirspell"
    ];

    shellAliases = {
      gs = "git status -sb";
      gd = "git diff";
      gds = "git diff --staged";
      gl = "git log --oneline --graph --decorate -20";
    };

    # Load ble.sh after prompt hooks (fnox, direnv, zoxide) so it wraps them cleanly,
    # and skip it in non-TTY, dumb, CI, or AI-agent shells.
    initExtra = lib.mkOrder 2500 ''
      if [[ -t 0 && -t 1 && ''${TERM:-dumb} != dumb && -z ''${BLE_DISABLE:-} && -z ''${CI:-} && -z ''${PI_CODING_AGENT:-}''${CODEX_SANDBOX:-}''${CLAUDECODE:-} ]]; then
        PS1='\[\e[1m\]▲\[\e[0m\] \[\e[94m\]\w\[\e[0m\]\n\[\e[35m\]❯\[\e[0m\] '

        if [[ -v BLE_VERSION ]] || source "${pkgs.blesh}/share/blesh/ble.sh" --attach=prompt; then
          ${lib.optionalString config.programs.fzf.enable ''
            _ble_contrib_fzf_base="${config.programs.fzf.package}/share/fzf"
            ble-import -d integration/fzf-completion
            ble-import -d integration/fzf-key-bindings
          ''}
          ${lib.optionalString config.programs.zoxide.enable ''
            ble-import -d integration/zoxide
          ''}
          ble-bind -f up   'history-search-backward immediate-accept:point=end:hide-status'
          ble-bind -f down 'history-search-forward immediate-accept:point=end:hide-status'
        fi
      fi
    '';
  };
}
