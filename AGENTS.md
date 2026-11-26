# Home Manager Configuration (`nothumancode/home`)

Personal Nix flake managing Home Manager configurations across workstations and remote Linux hosts/sandboxes.

## Layout

- `flake.nix` — Flake inputs (all following the root `nixpkgs`), one `pkgs` for `x86_64-linux`, shared `cachixConfig` and `unfreePackages` (plain data), the single `username` behind `homeConfigurations.rodat`, the repo formatter (`treefmt`), `apps.x86_64-linux.default` (`hm-remote-switch`), and `checks`.
- `home.nix` — Core Home Manager configuration shared across machines (imports `modules/*`, renders the unfree allowlist to `~/.config/nixpkgs/config.nix`, `~/.config/nix/nix.conf` substituters, `targets.genericLinux`, nix-index/comma, `services.cns`).
- `modules/` — Modular tool/shell/editor configs (`utilities.nix` defines `hm-switch`, `hm-check`, `hm-fmt`; `doppler.nix` holds the default Doppler project/config for bare `doppler` commands and the `withDopplerSecrets` launcher helper; `neovim.nix` installs the editor's plugins and servers from nixpkgs and links `neovim/` (`init.lua`, `lua/home/*.lua`, `colors/vercel.lua`), checked headless by `neovim/test.lua`).
- `.github/workflows/ci.yml` — Runs `nix flake check` and pushes built outputs to `thehuman` (not on pull requests). `update-flake-lock.yml` opens a weekly lock-update PR and dispatches CI on its branch. See [Updates and the cache](README.md#updates-and-the-cache).

## Commands

| Command | What it does |
| --- | --- |
| `hm-fmt` | Runs `nix fmt` in `~/.config/home-manager`: the flake's `treefmt` (`nixfmt`, `deadnix --edit`, `stylua`) over git-visible files. |
| `hm-check` | Runs `nix fmt -- --ci`, `statix check`, and `actionlint` on the working tree, then `nix flake check` (style check, `remote-switch` + `shellcheck`, the `home` activation package, and `neovim`, which runs `modules/neovim/test.lua` in headless Neovim). Passes extra flags (e.g. `-L`) to `nix flake check`. |
| `hm-check --lint` | Runs only the working-tree linters without invoking `nix flake check`. |
| `hm-switch` | With a local `~/.config/home-manager` checkout: `nh home switch -b backup` on it (native Nix build output + built-in package diff; `NH_ROM=1` opts back into the live build tree). Without one: runs `nix run --refresh github:nothumancode/home`, passing `GITHUB_TOKEN`/`GH_TOKEN`/`gh auth token` as a Nix access token when there is one (only to avoid anonymous GitHub API rate limits; the repository is public). Supports `--push` (push the new generation to `thehuman` Cachix with `CACHIX_AUTH_TOKEN` from Doppler; skipped on dry runs) and forwards `nh` flags like `-n` (dry run), `-a` (ask), `-u`/`-U <input>` (update lockfile, checkout only). |
| `nix run --refresh github:nothumancode/home` | Remote bootstrap/update without a checkout: switches the current `$USER` to the fetched flake revision via `nh home switch` (flags after `--` go to `nh`, e.g. `-- -n` for a dry run). Needs no token; with Doppler access (`doppler login` or `DOPPLER_TOKEN`) activation also logs `gh` in (see [Secrets](README.md#secrets)). |
| `home-manager switch --flake <ref>` / `nh home switch <ref>` | Also work bare, with no wrapper and no `--impure`: both select `homeConfigurations.$USER`. |
| `nix fmt` | The repo formatter (`nixfmt-tree` extended with `deadnix` and `stylua`); `nix fmt -- --ci` fails on unformatted files. |
| `nix flake check` | Runs all flake checks directly (useful before `hm-check` is activated). |

## Verification Workflow

1. After edits, run `hm-fmt` (or `nix fmt`) if formatting is needed.
2. Run `hm-check` (or `nix flake check -L` if `hm-check` is not yet installed in the active profile).
3. Remember: Nix flakes only see **git-tracked** files inside a git repo. Newly created files (e.g. under `.github/` or `modules/`) must be `git add`ed before `nix flake check` or `hm-switch` will include them. `hm-check --lint` reads the working tree but, like `nix fmt`, skips git-ignored paths (`.agents/`, `.claude/`).

## Conventions & Gotchas

- **Do not shadow `pkgs.*` in `extraSpecialArgs`:** `modules/utilities.nix` uses `with pkgs; [ ... cachix ... ]`, so the shared Cachix config is passed as `cachixConfig` (not `cachix`).
- **One user, `rodat`, everywhere:** `flake.nix` defines only `homeConfigurations.rodat` (`/home/rodat`). Machines use that account; a sandbox that runs as another user (e.g. `root`) aliases it for the activation instead of getting its own configuration (see [Sandboxes](README.md#sandboxes)). Do not reintroduce per-user configurations or `builtins.getEnv`/`--impure`.
- **Cachix binary caches:** `https://thehuman.cachix.org` and `https://nixpkgs-python.cachix.org` are defined once in `cachixConfig` in `flake.nix` and reused by `home.nix` and `hm-remote-switch`.
- **Cache trust is per machine, not scripted, and never via `trusted-users`:** whoever can write the store (`root`, or the owner of a single-user install) needs no setup (`hm-remote-switch` passes the public keys itself). Other users need the caches trusted by the Nix daemon once per machine; until then Nix warns (`ignoring untrusted substituter`) and builds locally. Trust the cache URLs, not the user: `trusted-users` lets every process of that user (coding agents included) reconfigure the daemon. `devenv.cachix.org` is listed because devenv projects pull from it by default. Either pass the two lines as `--extra-conf` to the Determinate installer, or run:

  ```sh
  sudo tee -a /etc/nix/nix.custom.conf <<'EOF'  # /etc/nix/nix.conf on non-Determinate installs
  extra-trusted-substituters = https://thehuman.cachix.org https://nixpkgs-python.cachix.org https://devenv.cachix.org
  extra-trusted-public-keys = thehuman.cachix.org-1:5e++Y7TlcHLBOmHnqv1bmgUp0QuFJn+XCzN/V0Y5/6w= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
  EOF
  sudo systemctl restart nix-daemon
  ```
- **Agent hooks are not declared in Nix:** a list declared in `programs.claude-code.settings` (or `programs.codex.hooks`) replaces the one in the agent's mutable settings file on every switch, wiping hooks other tools added. So `modules/brain.nix` leaves `programs.brain.enable*Integration` off and runs `brain install --quiet --claude --codex --pi` at activation instead; it only touches brain's own entries and writes nothing when they are current. Do not add `--service` (the watcher is the module's systemd unit; a second, hand-installed unit makes activation fail).
- **Secrets come from Doppler per command, never from the shell:** nothing exports secrets into interactive shells (no fnox, no shell hook). Commands that need credentials are `withDopplerSecrets` launchers, each with its own Doppler config, which is the boundary of what it gets: `claude` (`agents/claude-code`), Pi (`agents/pi`), twg (`tools/atlassian`), `modal` (`tools/modal`), `hm-switch --push` (`tools/nix`). Do not make a launcher fall back to another config. Without Doppler auth a launcher runs its command without secrets. Doppler auth is the user's choice (`doppler login` or `DOPPLER_TOKEN`); do not require either one. `global/lf` is only the default for bare `doppler` commands.
- **Activation must work without network or Doppler:** activation runs on every switch, in sandbox image builds, and offline. Its only network step is GitHub login (`home.activation.setupGithubAuth` in `modules/gh.nix`): one `doppler run --only-secrets` call per host config (single attempt, no fallback file): `tools/gh` for github.com and `tools/ghe` for GitHub Enterprise, each with `GH_HOST`, `GH_TOKEN` and `GIT_USER_NAME`/`_EMAIL` (`gh`'s own names). Never inherit either into another config: both define `GH_TOKEN`, which `gh` uses for github.com and `*.ghe.com` ahead of stored logins. When Doppler is not logged in or unreachable it warns and keeps the stored logins; it never fails the switch. There is no login daemon.
- **Project toolchains are not global:** compilers and package managers (Go, gcc/make/pkg-config, pnpm, bun, TypeScript, pinned Pythons) come from each project's own environment (`devenv.nix` or the project flake). Run one-off tools with `, <command>` (comma). Only `nodejs_24` and `python3` stay global, for agents and scripts.
- **`nh` and store paths:** `hm-remote-switch` passes `path:${self}`; a bare `/nix/store/...` argument makes `nh` treat it as a pre-built result instead of a flake.
