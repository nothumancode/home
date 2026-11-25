#!/usr/bin/env bash
set -euo pipefail
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
tmp=$(mktemp -d)
trap 'find "$tmp" -type d -exec chmod u+w {} +; rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/home/.local/bin" "$tmp/outside"
cp -- "$(command -v "${MISE_BIN:-mise}")" "$tmp/home/.local/bin/mise"
cd "$tmp/outside"
env -i HOME="$tmp/home" PATH="$tmp/home/.local/bin:/usr/bin:/bin" LANG=C.UTF-8 TERM=dumb CI=1 \
  bash -eu -o pipefail -s -- "$repo" "$tmp/checkout with spaces" <<'SMOKE'
repo=$1
checkout=$2
git clone -q "$repo" "$checkout"
bootstrap=(mise bootstrap --from "$repo" --from-dir "$checkout" --config-dir mise)
mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.pi/agent" "$HOME/.config/git"
echo '{"hooks":{"Stop":[]},"theme":"personal"}' >"$HOME/.claude/settings.json"
printf 'model = "personal"\n' >"$HOME/.codex/config.toml"
echo '{"packages":["local:my-extension"]}' >"$HOME/.pi/agent/settings.json"
echo '[test]' >"$HOME/.config/git/config"
echo '  mine = intact' >>"$HOME/.config/git/config"
"${bootstrap[@]}" --dry-run >plan.log 2>&1
grep -q 'brain install --quiet' plan.log
test ! -L "$HOME/.config/mise" && test ! -e "$HOME/.bashrc"
echo 'local completion rules' >"$HOME/.editorconfig"
if "${bootstrap[@]}" --only dotfiles --yes >conflict.log 2>&1; then exit 1; fi
grep -q '.editorconfig' conflict.log
grep -qx 'local completion rules' "$HOME/.editorconfig"
mv "$HOME/.editorconfig" "$HOME/.editorconfig.saved"
"${bootstrap[@]}" --yes
mise bootstrap status --missing --json >status.json
jq -e 'all(.tools[]; .installed) and (.tools | length >= 72) and (.packages == {}) and (.systemd.units | length == 0)' status.json >/dev/null
test "$(git config --get test.mine)" = intact
test "$(git config --get diff.tool)" = difftastic
grep -Fq "$checkout/shared/git/home.gitconfig" "$HOME/.config/git/config"
grep -Fq "$HOME/.config/git/enterprise.gitconfig" "$HOME/.config/git/config"
jq -e '.theme == "personal" and .hooks.Stop == [] and (.hooks.SessionStart | length == 1)' "$HOME/.claude/settings.json" >/dev/null
jq -e '.packages == ["local:my-extension"] and .defaultProvider == "openai"' "$HOME/.pi/agent/settings.json" >/dev/null
grep -q 'model = "personal"' "$HOME/.codex/config.toml"
test -s "$HOME/.pi/agent/extensions/brain-brief.ts"
test "$(stat -c %a "$HOME/.pi/agent/open-tui.json")" = 600
before=$(sha256sum "$HOME"/{.bashrc,.claude/settings.json,.codex/config.toml,.config/git/config})
mise bootstrap --yes
test "$before" = "$(sha256sum "$HOME"/{.bashrc,.claude/settings.json,.codex/config.toml,.config/git/config})"
mise dot status --missing
mise -E debian bootstrap packages status --json | jq -e 'tostring | contains("build-essential")' >/dev/null
test ! -e "$HOME/.config/systemd/user/dev.mise.cns.service"
mkdir "$HOME/fixture-bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$HOME/systemctl-requests"\n' >"$HOME/fixture-bin/systemctl"
chmod +x "$HOME/fixture-bin/systemctl"
env DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent PATH="$HOME/fixture-bin:$PATH" \
  mise -E services bootstrap linux systemd-units apply --yes
grep -Fq "$HOME/.local/bin/mise" "$HOME/.config/systemd/user/dev.mise.cns.service"
grep -Fq 'brain watch --interval 5' "$HOME/.config/systemd/user/dev.mise.brain.service"
grep -q 'daemon-reload' "$HOME/systemctl-requests"
export GITHUB_ENTERPRISE_HOST=git.example.test HOME_GIT_WORK_NAME='Work Identity' HOME_GIT_WORK_EMAIL=dev@work.example
mise -E enterprise dot apply --yes
git init -q example && git -C example remote add origin https://git.example.test/team/repo
test "$(git -C example config --get user.email)" = dev@work.example
test "$(git config --get user.email)" != dev@work.example

bash --rcfile "$HOME/.bashrc" -ic 'test "$HISTSIZE:$EDITOR" = 50000:nvim && alias gl && type z && type lg >/dev/null'
if command -v zsh >/dev/null; then zsh -dic 'alias ll && type z' </dev/null; fi
eval "$(mise env -s bash)"
doppler=$(mise which doppler)
mv "$doppler" "$doppler.saved"
printf '#!/bin/sh\nprintf "<%%s>" "$@"\n' >"$doppler"
chmod +x "$doppler"
test "$(pi 'a b')" = "<run><-p><vault><-c><prd><--only-secrets><LOGGLY_API_TOKEN><--only-secrets><LOGGLY_SUBDOMAIN><--only-secrets><EXA_API_KEY><--only-secrets><AI_GATEWAY_API_KEY><--><$(mise which pi)><a b>"
test "$(twg 'a b')" = "<run><-p><vault><-c><prd><--only-secrets><TWG_USER><--only-secrets><TWG_SITE><--only-secrets><TWG_TOKEN><--><$(mise which twg)><a b>"
mv "$doppler.saved" "$doppler"
test "$(node -p 'process.versions.node.split(".")[0]')" = 24
nvim --headless '+lua if vim.g.colors_name ~= "vercel" or not MiniPick or vim.fn.has("python3") ~= 1 then vim.cmd.cquit(1) end' +qa
sock="$HOME/tmux.sock"
trap 'tmux -S "$sock" kill-server 2>/dev/null || true' EXIT
tmux -S "$sock" new-session -d
test "$(tmux -S "$sock" show -sv extended-keys-format)" = csi-u
test "$(tmux -S "$sock" show -gv base-index)" = 1
SMOKE
