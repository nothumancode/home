# Home Manager

One configuration, `homeConfigurations.rodat`, for every x86_64 Linux machine and
sandbox. Day-to-day commands are in [Commands and conventions](#commands).

## Sandboxes

A sandbox activates once, at creation (or in its image build). It needs Nix and,
while this repository is private, a GitHub token:

```sh
NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN" nix run github:nothumancode/home
```

That works as is for a user named `rodat` with home `/home/rodat`. Where the
platform lets you pick the user, create that one (Vercel Sandbox:
`sandbox.createUser('rodat')`, then run commands through the returned handle).

Where it does not (Modal always runs as root and ignores `USER`), alias the home
instead. Home Manager only checks `$USER` and that `$HOME` is the expected
directory, so:

```sh
mkdir -p /home && ln -s "$HOME" /home/rodat   # with sudo when not root
USER=rodat HOME=/home/rodat NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN" \
  nix run github:nothumancode/home
```

The files land in the real home, so later shells need no special environment.
Use the same command to update a running sandbox.

### Modal

`modal-sandbox` does the above in a Modal image and starts a sandbox from it:

```sh
id=$(modal-sandbox)             # current main; or: modal-sandbox <commit|branch|tag>
fnox exec -- modal shell "$id"
```

To start with a repository checked out for an agent to work on, add
`--with-git-repo <url>`; it is cloned into `/root/<name>` on its default branch,
or on `--with-git-branch <branch>`. Without the flag nothing is cloned. The
GitHub token is used for the clone only and is not left in the sandbox.

The image is cached per commit, so only a new commit rebuilds it. The sandbox
stops after an hour (`--timeout <seconds>`) and belongs to the Modal app
`human-nix` (`--app <name>` for another). Modal credentials come from the
environment, `~/.modal.toml`, or fnox. While this repository is private, the
image build reads a token from a Modal secret, created once:

```sh
fnox exec -- modal secret create github GITHUB_TOKEN="$(gh auth token)"
```

## Deploy with Cachix

Cachix Deploy pushes a built generation to long-lived machines; each runs an
agent named after its hostname. Use a Cachix workspace backed by the `thehuman`
binary cache.

### Enroll a machine once

1. Add its hostname to `deployHosts` in [outputs.nix](outputs.nix).
2. On the machine, as `rodat`, store the workspace's agent token and switch:

   ```sh
   (umask 077; printf 'CACHIX_AGENT_TOKEN=%s\n' "$(fnox --if-missing error get CACHIX_AGENT_TOKEN)" \
     > ~/.config/cachix-agent.token)
   hm-switch
   journalctl --user -u cachix-agent.service -n 20
   ```

   Look for **Agent registered.** On a multi-user Nix install, trust the cache
   in the Nix daemon first (see [Commands and conventions](#commands)).
3. To keep the agent running after logout: `sudo loginctl enable-linger rodat`.
   To unenroll, delete the token file and stop `cachix-agent.service`.

### Deploy

```sh
export CACHIX_AUTH_TOKEN=$(fnox --if-missing error get CACHIX_AUTH_TOKEN)
export CACHIX_ACTIVATE_TOKEN=$(fnox --if-missing error get CACHIX_ACTIVATE_TOKEN)
spec=$(nix build --no-link --print-out-paths .#cachix-deploy)
cachix push thehuman "$spec"
cachix deploy activate "$spec"
```

This deploys to every machine in `deployHosts` and waits for them; an offline
machine applies it when its agent reconnects. Add `--agent <hostname>` for one
machine, or `--async` to not wait. The activate token comes from **Start a
Deployment** in the workspace; the agent token cannot start a deployment.

From GitHub: add the `CACHIX_ACTIVATE_TOKEN` secret next to `CACHIX_AUTH_TOKEN`,
then **Actions → CI → Run workflow** on `main` with the hostname as the agent.
Pushes, pull requests, and runs with a blank agent do not deploy.

Home Manager rejects conflicting unmanaged files on the target; resolve them
there and deploy again.

## Commands

| Command | What it does |
| --- | --- |
| `hm-fmt` | Formats all `*.nix` files (`nixfmt`) and editor Lua under `nix/modules/neovim`, `shared/nvim` and `mise/config/nvim` (`stylua`) in `~/.config/home-manager`. |
| `hm-check` | Runs working-tree linters (`nixfmt --check`, `statix`, `deadnix`, `stylua --check`, `actionlint`) followed by `nix flake check` (style check, `remote-switch` + `shellcheck`, the `home` activation package, and the Cachix Deploy manifest). Passes extra flags (e.g. `-L`) to `nix flake check`. |
| `hm-check --lint` | Runs only the fast working-tree linters without invoking `nix flake check`. |
| `hm-switch` | With a local `~/.config/home-manager` checkout: `nh home switch -b backup` on it (live build tree + built-in package diff). Without one: exports `GITHUB_TOKEN`/`GH_TOKEN`/`gh auth token` as a Nix access token and runs `nix run --refresh github:nothumancode/home`. Supports `--push` (push the new generation to `thehuman` Cachix; skipped on dry runs) and forwards `nh` flags like `-n` (dry run), `-a` (ask), `-u`/`-U <input>` (update lockfile, checkout only). |
| `nix run --refresh github:nothumancode/home` | Remote bootstrap/update without a checkout: switches the current `$USER` to the fetched flake revision via `nh home switch` (flags after `--` go to `nh`, e.g. `-- -n` for a dry run). While the repo is private, prefix it with `NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"` on a machine without `hm-switch`; once it is public no token is needed. |
| `home-manager switch --flake <ref>` / `nh home switch <ref>` | Also work bare, with no wrapper and no `--impure`: both select `homeConfigurations.$USER`. |
| `modal-sandbox [rev] [--app name] [--timeout s]` | Builds (or reuses) a Modal image with this configuration activated at `rev` (default: remote `main`, pinned to its commit) and prints the ID of a new sandbox in the Modal app `human-nix`. `--with-git-repo <url> [--with-git-branch <branch>]` also clones that repository into `/root/<name>`. Defined in `nix/modules/modal.nix`; see [Modal](#modal). |
| `nix build --no-link --print-out-paths .#cachix-deploy` | Builds a Cachix Deploy manifest for the configured x86_64 Linux agents without activating any of them. |
| `nix fmt` | Standard flake formatter (`nixfmt-tree`, Nix files only). |
| `nix flake check` | Runs all flake checks directly (useful before `hm-check` is activated). |

## Verification Workflow

1. After edits, run `hm-fmt` (or `nix fmt`) if formatting is needed.
2. Run `hm-check` (or `nix flake check -L` if `hm-check` is not yet installed in the active profile).
3. Remember: Nix flakes only see **git-tracked** files inside a git repo. Newly created files (e.g. under `.github/` or `nix/modules/`) must be `git add`ed before `nix flake check` or `hm-switch` will include them (`hm-check --lint` checks the working tree directly).

## Conventions & Gotchas

- **Do not shadow `pkgs.*` in `extraSpecialArgs`:** `nix/modules/utilities.nix` uses `with pkgs; [ ... cachix ... ]`, so the shared Cachix config is passed as `cachixConfig` (not `cachix`).
- **One user, `rodat`, everywhere:** `flake.nix` defines only `homeConfigurations.rodat` (`/home/rodat`). Machines use that account; a sandbox that runs as another user (e.g. `root`) aliases it for the activation instead of getting its own configuration (see [Sandboxes](#sandboxes)). Do not reintroduce per-user configurations or `builtins.getEnv`/`--impure`.
- **Cachix binary caches:** `https://thehuman.cachix.org` and `https://nixpkgs-python.cachix.org` are defined once in `cachixConfig` in `nix/outputs.nix` and reused by `home.nix` and `hm-remote-switch`.
- **Cache trust is per machine, not scripted:** whoever can write the store (`root`, or the owner of a single-user install) needs no setup (`hm-remote-switch` passes the public keys itself). Other users need the caches trusted by the Nix daemon once per machine; until then Nix warns (`ignoring untrusted substituter`) and builds locally. Either pass the two lines as `--extra-conf` to the Determinate installer, or run:

  ```sh
  sudo tee -a /etc/nix/nix.custom.conf <<'EOF'  # /etc/nix/nix.conf on non-Determinate installs
  extra-trusted-substituters = https://thehuman.cachix.org https://nixpkgs-python.cachix.org
  extra-trusted-public-keys = thehuman.cachix.org-1:5e++Y7TlcHLBOmHnqv1bmgUp0QuFJn+XCzN/V0Y5/6w= nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU=
  EOF
  sudo systemctl restart nix-daemon
  ```
- **Agent hooks are mutable:** `nix/modules/brain.nix` enables the upstream module’s `installHooks`; Brain manages its own entries without replacing other agents’ hooks. Do not install a second watcher service.
- **Cachix Deploy is opt-in per machine:** `nix/modules/cachix-deploy.nix` enables Home Manager's own `services.cachix-agent` with the name `%H` (the hostname), so every machine shares one generation. A machine is enrolled when its hostname is in `deployHosts` and `~/.config/cachix-agent.token` exists; without the file the unit is skipped. Sandboxes are not agents: they activate once at creation. The activation token belongs on the deployer, not the target.
- **`nh` and store paths:** `hm-remote-switch` passes `path:${self}`; a bare `/nix/store/...` argument makes `nh` treat it as a pre-built result instead of a flake.
