case $- in *i*) ;; *) return ;; esac
if [ -n "${ZSH_VERSION:-}" ]; then
  _home_shell=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
  _home_shell=bash
else
  return
fi

if ! command -v mise >/dev/null && [ -x "$HOME/.local/bin/mise" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
if [ "${MISE_SHELL:-}" != "$_home_shell" ] || ! typeset -f mise >/dev/null; then
  eval "$(mise activate "$_home_shell")"
fi

alias gs='git status -sb' gd='git diff' gds='git diff --staged' gl='git log --oneline --graph --decorate -20'
alias eza='eza --git --icons=never --group-directories-first'
alias ls=eza ll='eza -l' la='eza -a' lt='eza --tree' lla='eza -la'
alias vi=nvim vim=nvim vimdiff='nvim -d'

lg() {
  local newdir rc=0
  newdir=$(mktemp) || return 1
  LAZYGIT_NEW_DIR_FILE="$newdir" command lazygit "$@" || rc=$?
  if [ -s "$newdir" ]; then cd -- "$(cat "$newdir")" || rc=$?; fi
  rm -f -- "$newdir"
  return "$rc"
}

if [ "$_home_shell" = bash ]; then
  HISTSIZE=50000
  HISTFILESIZE=200000
  HISTCONTROL=ignoreboth:erasedups
  HISTIGNORE='ls:ll:la:lt:lla:cd:pwd:exit:clear:fg:bg'
  shopt -s histappend checkwinsize extglob globstar checkjobs cdspell dirspell
  if [ -z "${BASH_COMPLETION_VERSINFO:-}" ] && [ -r /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  fi
fi
if command -v fzf >/dev/null; then eval "$(fzf "--$_home_shell")"; fi
if command -v fnox >/dev/null; then eval "$(fnox activate "$_home_shell")"; fi
if command -v direnv >/dev/null; then eval "$(direnv hook "$_home_shell")"; fi
if command -v zoxide >/dev/null; then eval "$(zoxide init "$_home_shell")"; fi

if [ "$_home_shell" = bash ] && [ -t 0 ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] &&
  [ -z "${BLE_DISABLE:-}${CI:-}${PI_CODING_AGENT:-}${CODEX_SANDBOX:-}${CLAUDECODE:-}" ]; then
  PS1='\[\e[1m\]▲\[\e[0m\] \[\e[94m\]\w\[\e[0m\]\n\[\e[35m\]❯\[\e[0m\] '
  _home_ble=$(mise where http:blesh 2>/dev/null)
  if [ -r "$_home_ble/ble.sh" ] && . "$_home_ble/ble.sh" --attach=prompt; then
    if command -v fzf >/dev/null; then
      _ble_contrib_fzf_base=$(dirname "$(command -v fzf)")
      ble-import -d integration/fzf-completion
      ble-import -d integration/fzf-key-bindings
    fi
    if command -v zoxide >/dev/null; then ble-import -d integration/zoxide; fi
    ble-bind -f up 'history-search-backward immediate-accept:point=end:hide-status'
    ble-bind -f down 'history-search-forward immediate-accept:point=end:hide-status'
  fi
  unset _home_ble
fi
unset _home_shell
