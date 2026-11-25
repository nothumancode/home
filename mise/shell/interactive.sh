case $- in *i*) ;; *) return ;; esac
__home_shell_loaded=1

lg() {
  local newdir rc=0
  newdir=$(mktemp) || return 1
  LAZYGIT_NEW_DIR_FILE="$newdir" command lazygit "$@" || rc=$?
  if [ -s "$newdir" ]; then cd -- "$(cat "$newdir")" || rc=$?; fi
  rm -f -- "$newdir"
  return "$rc"
}

if [ "$MISE_SHELL" = bash ]; then
  HISTSIZE=50000
  HISTFILESIZE=200000
  HISTCONTROL=ignoreboth:erasedups
  HISTIGNORE='ls:ll:la:lt:lla:cd:pwd:exit:clear:fg:bg'
  shopt -s histappend checkwinsize extglob globstar checkjobs cdspell dirspell
  if [ -z "${BASH_COMPLETION_VERSINFO:-}" ] && [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  fi
fi
eval "$(fzf "--$MISE_SHELL")"
eval "$(fnox activate "$MISE_SHELL")"
eval "$(direnv hook "$MISE_SHELL")"
eval "$(zoxide init "$MISE_SHELL")"

if [ "$MISE_SHELL" = bash ] && [ -t 0 ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] &&
  [ -z "${BLE_DISABLE:-}${CI:-}${PI_CODING_AGENT:-}${CODEX_SANDBOX:-}${CLAUDECODE:-}" ]; then
  PS1='\[\e[1m\]▲\[\e[0m\] \[\e[94m\]\w\[\e[0m\]\n\[\e[35m\]❯\[\e[0m\] '
  _home_ble=$(mise where http:blesh 2>/dev/null)
  if [ -r "$_home_ble/ble.sh" ] && . "$_home_ble/ble.sh" --attach=prompt; then
    if command -v fzf >/dev/null; then
      ble-import -d integration/fzf-completion
      ble-import -d integration/fzf-key-bindings
    fi
    if command -v zoxide >/dev/null; then ble-import -d integration/zoxide; fi
    ble-bind -f up 'history-search-backward immediate-accept:point=end:hide-status'
    ble-bind -f down 'history-search-forward immediate-accept:point=end:hide-status'
  fi
  unset _home_ble
fi
