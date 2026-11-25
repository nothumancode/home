# Home environment monorepo

- Work from the repository root. Keep one root flake and lock so local checkouts, remote `nix run`, `nh` and bare Home Manager selectors keep working. The Nix app lives in `nix/`; see [its runbook](nix/README.md) for cache trust, user selection and switch behavior.
- The standalone `mise/` app installs *copies* into the user's global config. It must work without Nix, outside this checkout. Prefer registry tools, explicit upstream backends and native tasks. Document host packages and service prerequisites in [the setup guide](mise/README.md).
- Edit shared settings in `shared/`, not separate copies for each app. Leave agent settings writable, never replace hook lists on repeat setup, and keep credentials and live service state out of the repo.
- After Nix or shared edits, stage new files (flakes see only tracked files), run `hm-fmt` if needed and `hm-check`, or `nix flake check -L`. The Nix style check also checks all editor Lua and CI workflows.
- For Mise, run `mise/test` from the root, or `MISE_BIN=/absolute/path/to/mise mise/test`. It installs representative tools over HTTPS in a temporary home. Test substantial manifest or editor changes with a full isolated install as well. Never run setup, shell activation, secret fetches or service installation against the developer's actual home to test a change.
