# Mise home profile

This is a user-global alternative to Home Manager, tested on x86-64 Linux. It installs tool versions and copies ordinary, writable config files. It doesn't need Nix, start services, change your login shell, or sign in to anything. Review the [tool list](config.toml) and [personal defaults](../shared/) first: they include Tomas's Git identity, Pi's model/provider choices and its `defaultProjectTrust = always` policy.

## Install

1. Start with Git, Bash, Python 3.8+, curl, CA certificates, tar/xz and sha256sum. Use the [official stable installer](https://mise.jdx.dev/installing-mise.html) if Mise isn't already installed:

   ```bash
   installer=$(mktemp)
   curl --proto '=https' --proto-redir '=https' --tlsv1.2 -fsSL https://mise.run/bash -o "$installer" &&
     bash "$installer"
   rm -f "$installer"
   "$HOME/.local/bin/mise" --version
   ```

   This installer adds Mise activation to `~/.bashrc`. If you already have Mise on PATH, substitute `mise` for `~/.local/bin/mise` below. Use a current release; the registry and backends ship with Mise.

2. From this repository, inspect the plan, then install:

   ```bash
   ./mise/setup --dry-run
   ./mise/setup
   cd "$HOME"
   ~/.local/bin/mise install
   ~/.local/bin/mise exec -- nvim --version
   ```

   Setup copies the global manifest and session environment to `${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/conf.d/`; it doesn't replace your main Mise config. Neither the checkout nor the current working directory is needed afterwards. Project configs can still select other versions. The complete Linux install uses several GiB.

3. Add this **one line, once** to the end of `~/.bashrc` or `${ZDOTDIR:-$HOME}/.zshrc`, then open a new interactive shell:

   ```sh
   . "${XDG_CONFIG_HOME:-$HOME/.config}/home-env/shell.sh"
   ```

   It uses existing Mise activation or activates it, then loads aliases, history, completions, fzf, zoxide, direnv and fnox. Bash loads ble.sh last, only in an interactive terminal outside CI and coding agents (`BLE_DISABLE=1` opts out). Bash login profiles should source `~/.bashrc`. For scripts and editors not launched from an activated shell, use `mise exec -- <command>`.

### Existing files and updates

By default a different file or symlink stops setup **before it writes anything**. Use `--keep-existing` to skip conflicts, or `--backup` to move them to a sibling named `*.pre-home-mise` (numbered if needed) before installing. Both accept `--dry-run`. Setup won't write through symlinked directories. It never edits shell startup files.

Claude, Codex and Pi settings are **seeded only when missing**, even with `--backup`. This preserves hooks, project trust, extra Pi packages and live TUI preferences. For an existing agent, merge the desired keys from `shared/claude/`, `shared/codex/` or `shared/pi/` yourself. Pi's Docker MCP gateway is account-specific: configure your OAuth-enabled endpoint under `mcpServers.gateway` in `~/.pi/agent/mcp.json` if you use it; setup does not write this file.

Identical files are left untouched. To update, pull the repository and rerun setup with your conflict policy; run `mise install` from home for new tools. `mise upgrade` refreshes floating versions. Unlike the Nix lock, this profile doesn't pin every transitive dependency. To undo it, remove the files listed by setup, restore any backups and remove the shell source line. Do not delete your entire Mise data directory or agent state.

## What runs where

| Area | Mise profile |
| --- | --- |
| Development | Node 24, Python 3.13, Go, Bun, pnpm, uv, TypeScript, the lint/format CLIs, Dagu 2.27.0, KBTD, the Git tools, text/data/PDF and terminal utilities are in [config.toml](config.toml). Brain uses its own Python 3.14. pnpm/Node use the system's CA trust. |
| Shell, Git and tmux | Bash history, Git/eza aliases, `lg` directory switching, fzf previews, the bat style, direnv and fnox hooks, and tmux pane bindings/clipboard/modified keys are configured. Git uses delta, difftastic, LFS, nvimdiff and gh's credential helper. A higher-priority `~/.gitconfig` or `~/.tmux.conf` can override the XDG configuration; keep, merge or move it intentionally. |
| Neovim | Open `nvim` once with network access: its native package manager fetches eight pinned plugins. The theme, picker/keys, LSP, format-on-save, linting and EditorConfig are shared. Python and Node providers are installed. Run `mise run home-parsers` for the additional Tree-sitter parsers (Git, network, tar and a C compiler required). No Nix completion source, nil server or Nix-specific formatters. The TypeScript 6 fallback supplies tsserver when a project doesn't. |
| Agents, secrets and GitHub | Log in to Doppler and authorize the `vault/prd` project before using fnox or the `pi`/`twg` commands. Each wrapper passes only its named Doppler secrets and the real tool path. TWG uses `~/.agents/skills`; Pi reads its extensions from the writable agent settings and may need npm access and provider login. `mise run home-github-auth` explicitly syncs personal/enterprise gh auth and the conditional work identity. No credentials are required to run setup. |
| Brain and CNS | `mise run home-brain-hooks` installs or repairs Brain's own Claude, Codex and Pi hooks; approve Codex hooks in `/hooks` if prompted. For the watcher, run `brain service install` only on a host with user systemd. For CNS, `cns up --install` **starts** the daemon and installs a user service; do this from the configured home environment only on a machine you intend to pair. Its installer captures PATH; rerun it after moving the executable. On Linux add `Environment=NODE_USE_SYSTEM_CA=1 UV_SYSTEM_CERTS=true` under `[Service]` via `systemctl --user edit cns`, then restart it. Don't install a second service over a Home Manager unit. Pairing, login persistence and existing identities are host decisions. |
| OS tools | Use the distribution for the native compiler and Make, pkg-config, Bash/completion, Git, less, curl, DNS utilities, file, GNU tar, lsof, OpenSSH, rsync, socat, tree, unzip, wget, xz, zip and zstd. Linux's bubblewrap, iproute2 and psmisc also belong to the host. These aren't silently installed with sudo. |
| Nix only | Flakes, Home Manager generations, Cachix, nh, the `hm-*` commands, nix-direnv/devenv, nixfmt-tree, statix/deadnix and Nix build/inspection tools stay in the Nix app. Ordinary direnv still works. |

For a Debian/Ubuntu host missing the OS portion, the corresponding package list is:

```sh
sudo apt-get install bash bash-completion git python3 ca-certificates build-essential pkg-config less curl dnsutils file tar lsof openssh-client rsync socat tree unzip wget xz-utils zip zstd bubblewrap iproute2 psmisc
```

**Verification:** The profile was installed with stable Mise **2026.11.14** from the official Bash installer on x86-64 Linux. All 72 tool entries resolved in an isolated home without Nix on PATH. `mise/test` exercises global discovery outside the checkout, safe conflict handling, repeat setup, representative downloads, both shell integrations (Zsh when present), Git and tmux under a temporary HOME.

For backend and configuration details, start at the [official Mise index](https://mise.jdx.dev/llms.txt): [registry](https://mise.jdx.dev/registry.html), [configuration hierarchy](https://mise.jdx.dev/configuration.html), [shell activation](https://mise.jdx.dev/shell-setup.html) and [tasks](https://mise.jdx.dev/tasks/).
