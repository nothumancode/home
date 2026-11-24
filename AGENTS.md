# Home Manager Configuration (`thehumanworks/home`)

Personal Nix flake managing Home Manager configurations across workstations and remote Linux hosts/sandboxes.

## Layout

- `flake.nix` — Flake inputs, shared `cachixConfig`, `mkHome` helper, `homeConfigurations` (`rodat`, `root`, `tomas`), `apps.x86_64-linux.default` (`hm-remote-switch`), and `checks`.
- `home.nix` — Core Home Manager configuration shared across users (imports `modules/*`, sets `nixpkgs` unfree allowlist, `~/.config/nix/nix.conf` substituters, `services.cns`).
- `modules/` — Modular tool/shell/editor configs (`utilities.nix` defines `hm-switch`, `hm-check`, `hm-fmt`).
- `.github/workflows/ci.yml` — Runs `nix flake check` on `ubuntu-latest` and pushes built outputs to `thehuman.cachix.org` on `main` using `CACHIX_AUTH_TOKEN`.

## Commands

| Command | What it does |
| --- | --- |
| `hm-fmt` | Formats all `*.nix` files (`nixfmt`) and `modules/neovim` (`stylua`) in `~/.config/home-manager`. |
| `hm-check` | Runs working-tree linters (`nixfmt --check`, `statix`, `deadnix`, `stylua --check`, `actionlint`) followed by `nix flake check` (style check, `remote-switch` + `shellcheck`, and all `home-{rodat,root,tomas}` activation packages). Passes extra flags (e.g. `-L`) to `nix flake check`. |
| `hm-check --lint` | Runs only the fast working-tree linters without invoking `nix flake check`. |
| `hm-switch` | Switches Home Manager and prints `nvd diff`. Uses local `~/.config/home-manager#<user>` when present, or falls back to `github:thehumanworks/home#<user>` with `--refresh` and Cachix/GitHub-auth options on remotes without a checkout. Supports `--push` (push generation to `thehuman` Cachix) and `--remote` (force GitHub flake). |
| `nix run --refresh github:thehumanworks/home` | First-time remote bootstrap (no checkout needed). Auto-detects current user (`rodat`, `root`, `tomas`; override with `-- --user <name>`), configures Cachix options when trusted, forwards `GITHUB_TOKEN`/`gh auth token`, and runs `home-manager switch` + `nvd diff`. Dry run: `-- -n`. |
| `nix fmt` | Standard flake formatter (`nixfmt-tree`, Nix files only). |
| `nix flake check` | Runs all flake checks directly (useful before `hm-check` is activated). |

## Verification Workflow

1. After edits, run `hm-fmt` (or `nix fmt`) if formatting is needed.
2. Run `hm-check` (or `nix flake check -L` if `hm-check` is not yet installed in the active profile).
3. Remember: Nix flakes only see **git-tracked** files inside a git repo. Newly created files (e.g. under `.github/` or `modules/`) must be `git add`ed before `nix flake check` or `hm-switch` will include them (`hm-check --lint` checks the working tree directly).

## Conventions & Gotchas

- **Do not shadow `pkgs.*` in `extraSpecialArgs`:** `modules/utilities.nix` uses `with pkgs; [ ... cachix ... ]`, so the shared Cachix config is passed as `cachixConfig` (not `cachix`).
- **Adding a user:** Add an entry to `users` in `flake.nix` (`<username> = "<homeDirectory>";`). It automatically gets a `homeConfigurations.<user>`, a `checks.x86_64-linux.home-<user>`, and support in `hm-remote-switch`.
- **Cachix binary caches:** `https://thehuman.cachix.org` and `https://nixpkgs-python.cachix.org` are defined once in `cachixConfig` in `flake.nix` and reused by `home.nix`, `hm-remote-switch`, and `hm-switch`.
