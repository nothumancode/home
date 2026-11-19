# Working on this repository

This is a Home Manager flake for one person on Linux, WSL and macOS.
`README.md` describes how it is used.

- Check a change with `nix flake check`. It builds the Linux configuration
  and tests SecretSpec shell loading with fixtures. Evaluate the macOS configuration with
  `nix eval --raw .#checks.aarch64-darwin.home.drvPath`. Format with `nix fmt`.
- Nix reads only files that Git tracks. Stage a new file before you build.
- Put a platform difference in the module it belongs to, behind
  `pkgs.stdenv.hostPlatform.isDarwin` or `isLinux`. WSL cannot be detected at
  build time; detect it at run time.
- Never write a secret value, the age key or a `.env.keys` file into the
  repository. Declare names in `secretspec.toml`; resolve values only at runtime.
- `config/agents/AGENTS.md` is installed on every machine as the global
  context of each coding agent. Keep it short and true for all platforms.
