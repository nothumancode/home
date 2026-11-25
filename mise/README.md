# Bootstrap a home with Mise

This profile is for a personal x86-64 Linux account with Git and **Mise 2026.11.14 or newer**. It needs neither Nix nor root. It configures Tomas's Git identity, shell, editor and agent defaults (including Pi's `defaultProjectTrust = always`); review [the profile](config.toml), [tools](conf.d/tools.toml) and [shared settings](../shared/) before applying them.

## Install and update

From a directory **outside** this repository:

```sh
mise bootstrap --from https://github.com/nothumancode/home.git \
  --from-dir "$HOME/.dotfiles" --config-dir mise
```

Use your usual Git access to the private repository; an SSH URL also works. This is Mise's [global-config-from-a-subdirectory](https://mise.jdx.dev/bootstrap/from-repository.html#global-config-elsewhere) workflow: it keeps the monorepo at `~/.dotfiles`, links the global Mise config directory to its `mise/` subdirectory, deploys dotfiles, activates Bash and Zsh, installs tools, then runs the Brain hook integration. Keep that checkout in place. Tools, env, wrappers and tasks now work from **any directory**, without `-C` or a project-local trust prompt.

- **To preview first**, add `--dry-run`. With no checkout yet it previews *only the clone*. For a full preview, first run `git clone https://github.com/nothumancode/home.git ~/.dotfiles`, then run the command above with `--dry-run`. To try a PR before it lands, check out its branch in that clone.
- **If Mise isn't installed**, follow the [official installer](https://mise.jdx.dev/installing-mise.html) and put `~/.local/bin` on PATH for the first command. Check `mise --version`: the installer normally waits 24 hours after a release; set `MISE_SELF_UPDATE_MINIMUM_RELEASE_AGE=0s` for that install if you want the latest stable immediately. The shell-neutral `https://mise.run` installer leaves activation to bootstrap. The [Bash installer](https://mise.run/bash) also works, but appends an unmarked `mise activate bash` line to `~/.bashrc`; remove that line before bootstrap to avoid activating twice. Leave your other startup code in place.
- **To use it**, open a new interactive shell, or use `mise exec -- nvim` without shell activation. Mise manages only its activation block in each rc file. If your interactive Bash login profile doesn't source `~/.bashrc`, add that source line yourself.
- **To check or update**, run `cd ~ && mise bootstrap status --missing` or `mise dot diff`. `mise bootstrap` reapplies the local checkout; `mise bootstrap --update` fast-forwards it first. `mise upgrade` updates floating tool versions. This is not a locked Home Manager generation.

### Existing files

Choose one owner per home directory. Mise refuses to link its global config over a nonempty `~/.config/mise`; back it up yourself and keep the settings you want before adopting this profile. A bootstrap is **not a transaction**: an earlier phase (including that config link) can finish before a later one stops.

The `cli` dotfile group links individual files under `~/.config`, not entire application directories. At a managed target, an existing regular file blocks the link. Inspect it, merge or move it aside, then rerun. A foreign **symlink can be repointed without a prompt**: relinquish Home Manager ownership first, and inspect the plan rather than using `--force-dotfiles`. Links are live; edit their sources in the checkout.

Git config and ignore rules are named blocks. Other lines stay intact; `~/.gitconfig` can override the XDG Git defaults. Claude, Codex, Pi, fnox, gh and lazygit use native structured **missing-key merges**. Existing values, trust records and hooks survive; new agent config files are private. Mise treats arrays as one value, so it seeds the default Pi extensions on a fresh machine but **does not append** to your existing package list. Review [the list](../shared/pi/settings.json) to opt into additional extensions.

The declared targets use standard `~/.config`, `~/.claude`, `~/.codex`, `~/.pi/agent` and shell startup paths. The native target keys do not expand Tera or environment variables: changing `XDG_CONFIG_HOME`, `ZDOTDIR` or an agent's config directory does not relocate those entries. Adapt the declarations before applying on such hosts. The Git block itself renders the actual checkout and per-user enterprise include paths. No history watcher, tracked dotfiles, remote sync or secret-file templates are enabled.

## Host-specific choices

The base bootstrap never installs system packages, starts a service, fetches credentials or pairs a device. Select only what you need:

| Environment | Preview / apply | Effect |
| --- | --- | --- |
| `debian` | `mise -E debian bootstrap packages apply --dry-run`; omit `--dry-run` to install. | apt supplies native build tools, shell completion, GNU/Unix tools, OpenSSH, DNS and Linux diagnostics listed in [config.debian.toml](config.debian.toml). Installing missing packages needs the host administrator. On other distributions provide equivalents. |
| `services` | **After** the base install, `mise -E services bootstrap linux systemd-units apply --dry-run`; omit `--dry-run` on a host with user systemd to start them. | [Two user units](config.services.toml) launch the Brain watcher and CNS through the installed Mise executable. CNS binds port 47381 on all interfaces for paired devices and uses system CA settings. Enable this only on a host you intend to serve. |
| `enterprise` | Set `GITHUB_ENTERPRISE_HOST` (hostname), `HOME_GIT_WORK_NAME` and `HOME_GIT_WORK_EMAIL` in your local environment. Inspect `mise -E enterprise dot diff`, then `mise -E enterprise dot apply`. | Tera renders local Git credential and identity includes for HTTPS/SSH remotes on that host. Other remotes retain your personal identity. Supply your work identity explicitly instead of inferring it by querying gh on every bootstrap. No token appears in the templates. |

These are explicit `-E` selections, not permanent machine roles. Leaving out `-E` later doesn't undo deployed files or stop services. The generated units are **dev.mise.brain.service** and **dev.mise.cns.service**: manage those with `systemctl --user`, not with Brain's or CNS's service installer. Stop and disable competing units first. Use `mise bootstrap services remove brain` / `cns` to remove the Mise units. Review files and backups before removing dotfile entries; never delete an agent's whole mutable settings directory.

## Daily use and exceptions

- **Git and agents.** Log into Doppler and authorize `vault/prd` before launching Pi or TWG. Native command wrappers pass the corresponding allowlist and select the underlying binary from the home profile, not the current repository. `mise -C "$HOME" run home-github-auth` explicitly logs gh into github.com using Doppler; add `-E enterprise` to select the work host/token. You can use `gh auth login` instead. Brain's post-tools hook repairs its own agent integrations; approve new Codex hooks with `/hooks` if prompted. Pi's OAuth-enabled Docker MCP gateway and provider logins belong to the account: configure them locally, not in Git.
- **Editor.** Neovim fetches eight pinned plugins on first launch. `mise run home-parsers` builds the additional Tree-sitter parsers (network, Git, tar and a C compiler). The color scheme, keys, format-on-save and linting use the shared Lua sources. Node and Python providers and LSPs are included. No Nix package completion, nil server or Nix formatters are configured.
- **Shell and terminal.** Mise owns aliases, binary wrappers, PATH and activation. One shell dotfile handles the parts that must affect an interactive shell: history/shopt, `lg` changing directory, tool-supplied hooks and ble.sh keybindings. It runs once per shell; ble.sh skips non-TTY, CI and agent shells. tmux keeps the pane bindings, truecolor, clipboard and modified keys.
- **What stays in Nix.** Home Manager generations/rollback, cache trust, Cachix, nh, the switch/check/fmt utilities, nix-direnv/devenv and Nix inspection/formatting tools. Ordinary direnv, fnox, Git LFS, Dagu, Brain, CNS, KBTD and TWG have non-Nix counterparts here.

The [isolated integration test](../tests/mise.sh) bootstraps the actual committed profile, not a mock installer. For the native contracts, see the official [index](https://mise.jdx.dev/llms.txt), [bootstrap](https://mise.jdx.dev/bootstrap.html), [dotfiles](https://mise.jdx.dev/dotfiles.html), [environments](https://mise.jdx.dev/configuration/environments.html), [wrappers](https://mise.jdx.dev/dev-tools/shims.html#command-wrappers) and [Tera](https://mise.jdx.dev/templates.html).
