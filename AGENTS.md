# Home Manager Configuration (`thehumanworks/home`)

Personal Nix flake managing Home Manager configurations across workstations and remote Linux hosts/sandboxes.

## Layout

- `flake.nix` — Flake inputs, shared `cachixConfig` (plain data), the `users` list that generates `homeConfigurations.<user>`, `apps.x86_64-linux.default` (`hm-remote-switch`), and `checks`.
- `home.nix` — Core Home Manager configuration shared across users (imports `modules/*`, sets `nixpkgs` unfree allowlist, `~/.config/nix/nix.conf` substituters, `services.cns`).
- `modules/` — Modular tool/shell/editor configs (`utilities.nix` defines `hm-switch`, `hm-check`, `hm-fmt`).
- `.github/workflows/ci.yml` — Runs `nix flake check` on `ubuntu-latest` and pushes built outputs to `thehuman.cachix.org` on `main` using `CACHIX_AUTH_TOKEN`.

## Commands

| Command | What it does |
| --- | --- |
| `hm-fmt` | Formats all `*.nix` files (`nixfmt`) and `modules/neovim` (`stylua`) in `~/.config/home-manager`. |
| `hm-check` | Runs working-tree linters (`nixfmt --check`, `statix`, `deadnix`, `stylua --check`, `actionlint`) followed by `nix flake check` (style check, `remote-switch` + `shellcheck`, and one `home-<user>` activation package per entry in `users`). Passes extra flags (e.g. `-L`) to `nix flake check`. |
| `hm-check --lint` | Runs only the fast working-tree linters without invoking `nix flake check`. |
| `hm-switch` | With a local `~/.config/home-manager` checkout: `nh home switch -b backup` on it (live build tree + built-in package diff). Without one: exports `GITHUB_TOKEN`/`GH_TOKEN`/`gh auth token` as a Nix access token and runs `nix run --refresh github:thehumanworks/home`. Supports `--push` (push the new generation to `thehuman` Cachix; skipped on dry runs) and forwards `nh` flags like `-n` (dry run), `-a` (ask), `-u`/`-U <input>` (update lockfile, checkout only). |
| `nix run --refresh github:thehumanworks/home` | Remote bootstrap/update without a checkout: switches the current `$USER` to the fetched flake revision via `nh home switch` (flags after `--` go to `nh`, e.g. `-- -n` for a dry run). While the repo is private, prefix it with `NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"` on a machine without `hm-switch`; once it is public no token is needed. |
| `home-manager switch --flake <ref>` / `nh home switch <ref>` | Also work bare, with no wrapper and no `--impure`: both select `homeConfigurations.$USER`. |
| `nix fmt` | Standard flake formatter (`nixfmt-tree`, Nix files only). |
| `nix flake check` | Runs all flake checks directly (useful before `hm-check` is activated). |

## Verification Workflow

1. After edits, run `hm-fmt` (or `nix fmt`) if formatting is needed.
2. Run `hm-check` (or `nix flake check -L` if `hm-check` is not yet installed in the active profile).
3. Remember: Nix flakes only see **git-tracked** files inside a git repo. Newly created files (e.g. under `.github/` or `modules/`) must be `git add`ed before `nix flake check` or `hm-switch` will include them (`hm-check --lint` checks the working tree directly).

## Conventions & Gotchas

- **Do not shadow `pkgs.*` in `extraSpecialArgs`:** `modules/utilities.nix` uses `with pkgs; [ ... cachix ... ]`, so the shared Cachix config is passed as `cachixConfig` (not `cachix`).
- **Users are a list, not impure lookups:** `homeConfigurations` is generated from `users` in `flake.nix` (`rodat`, `root`, `tomas`; home directory is `/root` or `/home/<user>`). A new username is a one-word addition there. Do not reintroduce `builtins.getEnv`/`--impure`.
- **Cachix binary caches:** `https://thehuman.cachix.org` and `https://nixpkgs-python.cachix.org` are defined once in `cachixConfig` in `flake.nix` and reused by `home.nix` and `hm-remote-switch`.
- **Cache trust is per machine, not scripted:** `root` needs no setup (`hm-remote-switch` passes the public keys itself). Unprivileged users need the caches trusted by the Nix daemon once per machine; until then Nix warns (`ignoring untrusted substituter`) and builds locally. Either pass the two lines as `--extra-conf` to the Determinate installer, or run:

  ```sh
  sudo tee -a /etc/nix/nix.custom.conf <<'EOF'  # /etc/nix/nix.conf on non-Determinate installs
  extra-trusted-substituters = https://thehuman.cachix.org https://nixpkgs-python.cachix.org
  extra-trusted-public-keys = thehuman.cachix.org-1:5e++Y7TlcHLBOmHnqv1bmgUp0QuFJn+XCzN/V0Y5/6w= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
  EOF
  sudo systemctl restart nix-daemon
  ```
- **Agent hooks are not declared in Nix:** a list declared in `programs.claude-code.settings` (or `programs.codex.hooks`) replaces the one in the agent's mutable settings file on every switch, wiping hooks other tools added. So `modules/brain.nix` leaves `programs.brain.enable*Integration` off and runs `brain install --quiet --claude --codex --pi` at activation instead; it only touches brain's own entries and writes nothing when they are current. Do not add `--service` (the watcher is the module's systemd unit; a second, hand-installed unit makes activation fail).
- **`nh` and store paths:** `hm-remote-switch` passes `path:${self}`; a bare `/nix/store/...` argument makes `nh` treat it as a pre-built result instead of a flake.
