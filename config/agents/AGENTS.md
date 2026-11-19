# Environment

Nix Home Manager configures this machine from `~/.config/home-manager`. The
same configuration runs on Linux, WSL and macOS.

- These tools are on `PATH` on every platform: `rg`, `fd`, `jq`, `yq`,
  `ast-grep`, `gh`, `git`, `shellcheck`, `shfmt`, `make`, `curl`, `hyperfine`,
  `node` and `npm`, `python3`, `uv`, `nix`. On macOS, `sed`, `grep`, `find`,
  `awk`, `tar` and the coreutils are the GNU versions, as on Linux.
- To use a tool that is not installed, run it with
  `nix shell nixpkgs#<package> -c <command>`. Nothing stays installed.
- For Python, use `uv` (`uv run`, `uvx`, `uv venv`).
- A project can have an `.envrc` file. If its variables are missing in your
  shell, run the command through `direnv exec . <command>`.
- Files under `~/.config`, `~/.claude` and `~/.pi` that are symlinks into
  `/nix/store` are read-only. To change one, edit `~/.config/home-manager`
  and run `home-manager switch -b backup --flake ~/.config/home-manager`.

# Secrets

API tokens are environment variables. They come from a sops-encrypted file
in the Home Manager repository.

- `secrets status` lists the variable names. It does not show values.
- Do not print a token, write it to a file, or put it in a commit, a log or
  a command line that is echoed back.
- Do not read `~/.config/sops/age/keys.txt` and do not decrypt
  `secrets/identity.age`.
