# Home

One Home Manager configuration for Linux, WSL and macOS: shell, Git, Neovim,
command-line tools, coding agents (Claude Code, Pi) and their secrets.

## Set up a new machine

Install Nix with `nix-command` and `flakes` enabled, then open a new terminal.
The [standalone Home Manager](https://nix-community.github.io/home-manager/nix-flakes/standalone.html)
configuration already exists in this repository; no `init` or setup script is needed.

```sh
# Clone this repository (sign in with gh first if needed).
nix shell nixpkgs#gh nixpkgs#git -c gh repo clone thehumanworks/home ~/.config/home-manager
cd ~/.config/home-manager

# First activation uses the Home Manager CLI pinned in flake.lock.
nix run .#home-manager -- switch -b backup --flake .
```

The account name must be in `users` in [`flake.nix`](flake.nix). Open a new
terminal after activation; use `hms` for subsequent switches.

## Daily use

| Task | Command |
| --- | --- |
| Apply a change to this repository | `hms` |
| Update all packages | `nix flake update`, then `hms` |
| Check a change before applying it | `nix flake check` |
| Format Nix files | `nix fmt` |

## Binary caches

After activation, local builds can download signed paths from
[`thehuman`](https://thehuman.cachix.org) and
[`nixpkgs-python`](https://nixpkgs-python.cachix.org) in addition to the
standard Nix caches. Both are public: no token is needed and builds are not
uploaded. The URLs and public signing keys are in
[`config/nix/cachix.conf`](config/nix/cachix.conf). CI uses the same file.
To use the caches on the very first switch too, prefix the `nix run` command
above with `NIX_CONFIG="$(cat config/nix/cachix.conf)"`.

Home Manager adds `!include hm-cachix.conf` to your user `nix.conf`, leaving
private settings in place. Check the result with `nix config show substituters`.
If you have old `substituters =` or `trusted-public-keys =` lines there, remove
redundant entries or change those settings to `extra-…` to keep system defaults.

Home Manager does not edit `/etc/nix`. If a multi-user Nix daemon reports that
it is ignoring an untrusted cache, have the administrator add the same public
cache settings to the daemon configuration and reload the daemon. With
Determinate Nix, `/etc/nix/nix.custom.conf` is the local override included by
the generated `/etc/nix/nix.conf`.

## Shell secrets

[`secretspec.toml`](secretspec.toml) declares which variables belong in every
interactive Bash and Zsh shell. Home Manager installs the shell hook, **not the
values**. At shell startup it runs [`secretspec export`](https://secretspec.dev/reference/cli/#export)
against the checkout's manifest and loads the `default` profile only on success.
This works from any directory. Programs started from that shell (including
coding agents) inherit the variables; unrelated services, GUI apps and other
users do not. Use a separate project manifest and `secretspec run -- COMMAND`
for secrets that should not be global.

The manifest reads from [Doppler](https://secretspec.dev/providers/doppler/)
using the `doppler` alias. Its token comes from a SecretSpec credential source
named **`bootstrap`**. That's a provider alias, not a shell script. On this
setup it uses the [age provider](https://secretspec.dev/providers/age/) and
the encrypted `secrets.age` next to the manifest.

On a new machine, install the **matching private age identity** outside the
checkout (mode 600). Register the alias in your user SecretSpec configuration
if it isn't there already, substituting the actual identity file path:

```sh
secretspec config global provider add bootstrap 'age://secrets.age?identity=/absolute/path/to/your/identity.txt'
```

An existing encrypted credential needs no new login. Only when provisioning
or replacing the Doppler token, run `secretspec config provider login doppler`
**from the checkout**; it prompts privately and writes to the credential store.
Do not put tokens or private keys in the manifest, Nix settings or Git.

Open a new terminal after changing credentials or declarations. If the provider
is unavailable the shell still opens and inherits its previous environment. To
diagnose a failure, or check inheritance, without printing a value:

```sh
(cd ~/.config/home-manager && secretspec export --profile default >/dev/null)
printenv EXA_API_KEY >/dev/null && echo 'EXA_API_KEY is exported'
```

## Platform notes

- **WSL**: for a multi-user Nix installation, enable systemd in `/etc/wsl.conf`
  (`[boot]` and `systemd=true`) and run `wsl.exe --shutdown` from Windows.
- **macOS**: Zsh is the login shell and gets the same aliases, prompt and
  secrets as Bash. `sed`, `grep`, `find`, `awk`, `tar` and the coreutils are the
  GNU versions, so commands behave as they do on Linux. The system versions
  stay in `/usr/bin`.
- **NixOS**: set `targets.genericLinux.enable = false` in `home.nix`.

## Layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Inputs, account names, one configuration per platform |
| `home.nix` | Module list and settings shared by all platforms |
| `modules/shell.nix` | Bash, Zsh, prompt, fzf, zoxide, direnv |
| `modules/packages.nix` | Command-line tools |
| `modules/secretspec.nix` | Loads the home manifest into interactive Bash and Zsh at runtime |
| `modules/git.nix` | Git settings, GitHub sign-in through `gh`, delta |
| `modules/neovim.nix`, `config/nvim` | Editor, language servers, formatters |
| `modules/claude.nix`, `modules/pi.nix`, `modules/mcp.nix` | Coding agents and their MCP servers |
| `modules/agents.nix`, `config/agents` | Context given to every coding agent |
| `modules/herdr.nix` | Terminal workspace manager |
| `themes/` | One color palette for Neovim, Pi, herdr and the prompt |
