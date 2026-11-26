# Home Manager

One configuration, `homeConfigurations.rodat`, for every x86_64 Linux machine and
sandbox. Day-to-day commands are in [AGENTS.md](AGENTS.md).

## Sandboxes

A sandbox activates once, at creation (or in its image build). It needs only Nix:

```sh
nix run github:nothumancode/home
```

That works as is for a user named `rodat` with home `/home/rodat`. Where the
platform lets you pick the user, create that one (Vercel Sandbox:
`sandbox.createUser('rodat')`, then run commands through the returned handle).

Where it does not (Modal always runs as root and ignores `USER`), alias the home
instead. Home Manager only checks `$USER` and that `$HOME` is the expected
directory, so:

```sh
mkdir -p /home && ln -s "$HOME" /home/rodat   # with sudo when not root
USER=rodat HOME=/home/rodat nix run github:nothumancode/home
```

The files land in the real home, so later shells need no special environment.
Use the same command to update a running sandbox.

To log `gh` in during that activation, pass the `GH_*` variables
([Secrets](#secrets)) through the platform's secret mechanism. Leave them out of
image builds: headless `gh` keeps its token in plain text in
`~/.config/gh/hosts.yml`, so the image would carry it. Give the running sandbox
`GH_TOKEN` instead; `gh` and its git credential helper read it directly.

### Modal

Modal runs as root, so the image uses the alias above. Pin the configuration to
a commit: Modal reuses a cached layer until its definition changes.

```python
image = (
    modal.Image.debian_slim()
    .apt_install("ca-certificates", "curl", "git", "gnupg")
    # Modal's builder fails the installer's first Nix build unless its output goes to a file.
    .run_commands(
        "curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix"
        " | sh -s -- install linux --extra-conf 'sandbox = false' --init none --no-confirm"
        " >/tmp/nix-install.log 2>&1 || { cat /tmp/nix-install.log; exit 1; }"
    )
    .run_commands(
        "mkdir -p /home && ln -s /root /home/rodat"
        " && PATH=/nix/var/nix/profiles/default/bin:$PATH USER=rodat HOME=/home/rodat"
        " nix run github:nothumancode/home/<commit>"
    )
    # The activated profile first, so commands in the sandbox find its tools.
    .env({"PATH": "/home/rodat/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"})
)
```

Then `fnox exec -- modal shell <sandbox-id>` opens a shell in a sandbox created
from it.

## Updates and the cache

CI builds every push to `main` and pushes the result to the `thehuman` Cachix
cache; pull requests build without pushing. Every Monday the **Update
flake.lock** workflow opens a pull request with new input revisions and starts a
CI run on its branch, so the new generation is cached before you merge and run
`hm-switch` (or `nix run github:nothumancode/home` on a machine without a
checkout).

## Secrets

fnox resolves secrets from Doppler (`vault`/`prd`, set once in
`modules/doppler.nix`). Credentials are declared with `env = "exec"`, so the
shell hook never exports them: use them per command, for example
`fnox exec -- cachix push thehuman <path>` or `fnox exec -- modal shell <id>`.
Pi and twg get only their own secrets through `doppler run --only-secrets`.

GitHub logins do not come from Doppler. Activation logs `gh` in only from
tokens passed to the switch, and stores them in gh's own credential store:

| Variables | Effect |
| --- | --- |
| `GH_TOKEN` (and optionally `GH_HOST`, default `github.com`) | logs in to that host |
| `GH_ENTERPRISE_HOST` + `GH_ENTERPRISE_TOKEN` | logs in to the enterprise host and writes its git credential helper and work identity (`~/.config/git/enterprise*.gitconfig`) |
| `GH_ENTERPRISE_HOST` alone | writes the git config for a host you already logged in to by hand |

Without them activation makes no network call. It warns about each host that is
not set up yet and prints the commands to fix it, for example:

```sh
read -rs GH_TOKEN; GH_TOKEN=$GH_TOKEN hm-switch
```

Anywhere you can run a command, the first activation is the same: run
`nix run github:nothumancode/home` with the variables set, or without them and
follow the warnings. Over SSH, send your local tokens on stdin to keep them out
of shell history and the process list:

```sh
printf '%s\n%s\n' "$(gh auth token)" "$(gh auth token -h "$GHE_HOST")" | ssh host \
  "read -r GH_TOKEN; read -r GH_ENTERPRISE_TOKEN; export GH_TOKEN GH_ENTERPRISE_TOKEN GH_ENTERPRISE_HOST=$GHE_HOST
   nix run --refresh github:nothumancode/home"
```

After rotating a token, run the switch again with the new one set.
