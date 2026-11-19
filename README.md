# Home

One Home Manager configuration for Linux, WSL and macOS: shell, Git, Neovim,
command-line tools, coding agents (Claude Code, Pi) and their secrets.

## Set up a new machine

```sh
# 1. Install Nix, then open a new terminal.
curl --proto '=https' --tlsv1.2 -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install

# 2. Sign in to GitHub and clone this repository.
nix shell nixpkgs#gh nixpkgs#git -c sh -c \
  'gh auth login && gh repo clone thehumanworks/home ~/.config/home-manager'

# 3. Activate. If the repository has a sops key, unlock it when prompted.
~/.config/home-manager/bootstrap.sh
```

Open a new terminal when the script finishes. `bootstrap.sh` is safe to run
again, and it installs Nix itself when step 1 was skipped.

The account name must be in `users` in [`flake.nix`](flake.nix). The same name
works on every platform; the script tells you when a name is missing.

## Daily use

| Task | Command |
| --- | --- |
| Apply a change to this repository | `hms` |
| Update all packages | `nix flake update`, then `hms` |
| Check a change before applying it | `nix flake check` |
| Format Nix files | `nix fmt` |

## Secrets

When `secrets/env.yaml` is absent, Bash and Zsh can load the variables declared
in [`secretspec.toml`](secretspec.toml). Shell startup tries SecretSpec if you
have a SecretSpec configuration, `SECRETSPEC_PROVIDER`, or `DOPPLER_TOKEN`.
It uses the manifest in the checkout so relative providers can find
`secrets.age`. Missing credentials leave the shell usable without the secrets;
no token is needed to build or activate Home Manager.

To diagnose a provider without printing secret values, run
`(cd ~/.config/home-manager && secretspec export >/dev/null)`.

To use [sops](https://getsops.io) instead, run `secrets init`, then
`secrets set NAME` for each variable you need. Once the configuration includes
`secrets/env.yaml`, shells load only that file and do not contact Doppler.
The sops environment file is encrypted with one [age](https://age-encryption.org) key.

| File | Content |
| --- | --- |
| `secrets/env.yaml` | The secrets. Names are readable, values are encrypted. |
| `secrets/identity.age` | The age key, encrypted with your passphrase. |
| `.sops.yaml` | The public half of the key. |
| `~/.config/sops/age/keys.txt` | The usable key on each machine. Not in Git. |

The passphrase is the only thing you carry between machines. Keep it in a
password manager. `bootstrap.sh` (or `secrets unlock`) uses it once per machine
to write the key file.

Each entry of `secrets/env.yaml` becomes an environment variable in every
interactive Bash and Zsh session. Programs started from that shell, coding
agents included, inherit it. Put a token there only if every such program may
read it.

| Task | Command |
| --- | --- |
| List the variable names | `secrets status` |
| Add or change a variable | `secrets set NAME` |
| Remove a variable | `secrets unset NAME` |
| Edit several at once | `sops secrets/env.yaml` (keep the file flat: `NAME: value`) |
| Install the key on this machine | `secrets unlock` |
| Replace the key and passphrase | `secrets rotate` |

After a change, commit, run `hms` and open a new terminal. A variable that is
already set in a shell keeps its value.

If a machine or the passphrase is lost, run `secrets rotate` and also replace
each token at its provider. Rotation cannot protect values that are already in
the Git history.

### Secrets for one project

Give the project its own sops file and load it with direnv. The variables then
exist only inside that directory.

```sh
age-keygen -y ~/.config/sops/age/keys.txt   # prints your public key
sops encrypt --age <public key> -i secrets.yaml
echo 'use sops' >.envrc && direnv allow
```

For one command without direnv: `sops exec-env secrets.yaml '<command>'`.

## Platform notes

- **WSL**: Nix needs systemd. If `bootstrap.sh` reports that systemd is not
  running, add `[boot]` and `systemd=true` to `/etc/wsl.conf` and run
  `wsl.exe --shutdown`. Nothing else in this configuration needs systemd.
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
| `modules/secrets.nix` | Loads sops or SecretSpec variables into the shell; `use sops` for direnv |
| `modules/git.nix` | Git settings, GitHub sign-in through `gh`, delta |
| `modules/neovim.nix`, `config/nvim` | Editor, language servers, formatters |
| `modules/claude.nix`, `modules/pi.nix`, `modules/mcp.nix` | Coding agents and their MCP servers |
| `modules/agents.nix`, `config/agents` | Context given to every coding agent |
| `modules/herdr.nix` | Terminal workspace manager |
| `scripts/secrets.sh` | The `secrets` command |
| `themes/` | One color palette for Neovim, Pi, herdr and the prompt |
