# Home Manager

One configuration, `homeConfigurations.rodat`, for every x86_64 Linux machine and
sandbox. Day-to-day commands are in [AGENTS.md](AGENTS.md).

## Sandboxes

A sandbox activates once, at creation (or in its image build). It needs Nix and,
while this repository is private, a GitHub token:

```sh
NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN" nix run github:thehumanworks/home
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
  nix run github:thehumanworks/home
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

## Updates and the cache

CI builds every push to `main` and pushes the result to the `thehuman` Cachix
cache; pull requests build without pushing. Every Monday the **Update
flake.lock** workflow opens a pull request with new input revisions and starts a
CI run on its branch, so the new generation is cached before you merge and run
`hm-switch` (or `nix run github:thehumanworks/home` on a machine without a
checkout).

## Secrets

fnox resolves secrets from Doppler (`vault`/`prd`, set once in
`modules/doppler.nix`). Credentials are declared with `env = "exec"`, so the
shell hook never exports them: use them per command, for example
`fnox exec -- cachix push thehuman <path>` or `fnox exec -- modal shell <id>`.
Pi and twg get only their own secrets through `doppler run --only-secrets`.

GitHub logins (github.com and the enterprise host) are synced from Doppler by
the `setup-github-auth` user service once per login session. After rotating a
token, run `systemctl --user restart setup-github-auth`.
