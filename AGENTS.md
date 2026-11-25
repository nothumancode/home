# Home environment monorepo

- Work from the repository root. Keep one root flake and lock so local checkouts, remote `nix run`, `nh` and bare Home Manager selectors keep working. The Nix app lives in `nix/`; see [its runbook](nix/README.md) for cache trust, user selection and switch behavior.
- The standalone `mise/` app is a global Mise config directory. Use native bootstrap, dotfile groups/edits, shell activation, wrappers, lifecycle hooks and opt-in environments; don't reintroduce a custom installer. See [the setup guide](mise/README.md) for stable-checkout and conflict behavior.
- Edit shared settings in `shared/`, not separate copies for each app. Leave agent settings writable, never replace hook lists on repeat setup, and keep credentials and live service state out of the repo.
- After Nix or shared edits, stage new files (flakes see only tracked files), run `hm-fmt` if needed and `hm-check`, or `nix flake check -L`. The Nix style check also checks all editor Lua and CI workflows.
- For Mise, run `tests/mise.sh` from the root, or `MISE_BIN=/absolute/path/to/mise tests/mise.sh`. It clones the committed revision, bootstraps the full profile in a temporary home and stubs systemctl and credential forwarding. Never run these checks against the developer's actual home.
