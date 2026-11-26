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

To log `gh` in during that activation, give it Doppler access
([Secrets](#secrets)), for example a `DOPPLER_TOKEN` through the platform's
secret mechanism. Leave it out of image
builds: headless `gh` keeps its token in plain text in `~/.config/gh/hosts.yml`,
so the image would carry it. Give the running sandbox `DOPPLER_TOKEN` and rerun
the switch there, or give it `GH_TOKEN`, which `gh` and its git credential
helper read directly.

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

Then `modal shell <sandbox-id>` opens a shell in a sandbox created from it.

## Neovim

`modules/neovim.nix` pins every plugin, parser and language server through
`flake.lock`; nothing downloads at startup. Press **Space** and pause for the
key guide. `:Theme light`, `:Theme dark` or Space u t choose the Geist palette
and the choice survives restart; `:Theme auto` follows the terminal again.
`:checkhealth home` lists every server, formatter and tool the editor starts.

| Keys | Action |
| --- | --- |
| Space f f / f g / f w / f b / f o | Find a file, search text, grep the word, switch buffer, recent files |
| Space e / Space E / Space ? | Explore from this file or the working directory, find a keybinding |
| g d / g r r / g r i / g y / K | Definition, references, implementation, type, documentation |
| Space c a / c r / c f / c o | Code action, rename, format, organize imports |
| Space x x / x b / [d / ]d | Workspace or buffer diagnostics, previous or next diagnostic |
| Space g g / g l / g b / g h / g d | Lazygit, commits, history at cursor, changed hunks, diff overlay |
| Space a p / a c / a l / a t | Pi, Codex, Claude Code or a shell at the project root (reopens a running one) |
| Space a b / a w | Search agent history with Brain, explore a GitHub repo with WIT |
| Space u f / u F / u h / u d / u c | Format on save (buffer / all), inlay hints, diagnostic lines, sticky scope |
| af/if, ac/ic, ao/io | Function, class and block text objects; `gS` splits or joins arguments |

Ctrl-Q leaves terminal input (Esc stays with the agent). Python uses ty for
types and navigation and Ruff for lint and fixes; icons are ASCII, so no Nerd
Font is needed.

## Updates and the cache

CI builds every push to `main` and pushes the result to the `thehuman` Cachix
cache; pull requests build without pushing. Every Monday the **Update
flake.lock** workflow opens a pull request with new input revisions and starts a
CI run on its branch, so the new generation is cached before you merge and run
`hm-switch` (or `nix run github:nothumancode/home` on a machine without a
checkout).

## Secrets

Every secret comes from Doppler, through the `doppler` CLI with whatever auth
you give it: `doppler login`, or a `DOPPLER_TOKEN` in the environment. Nothing
exports secrets into the shell. Each command that needs credentials is a
launcher for its own Doppler config, and gets all of that config's secrets:

| Command | Doppler project/config |
| --- | --- |
| `claude` | `agents`/`claude-code` |
| `pi` | `agents`/`pi` |
| `twg` | `tools`/`atlassian` |
| `modal` | `tools`/`modal` |
| `hm-switch --push` (`cachix push`) | `tools`/`nix` |

Without Doppler auth a launcher starts the command without secrets, so a login
the tool stored itself still works. A bare `doppler run` or `doppler secrets`
uses `global`/`lf` (set in `modules/doppler.nix`), for example
`doppler run -- cachix push thehuman <path>`. With a service account token,
give the account read access to every project above.

GitHub logins happen at activation. Each switch reads one Doppler config per
host and stores the tokens in `gh`'s own credential store, so `gh` and git need
no Doppler afterwards. Both configs use `gh`'s own names, so
`doppler run -p tools -c ghe -- gh ...` also works on its own. Keep them out of
`global`/`lf`: both define `GH_TOKEN`, and `gh` uses that one variable for
`github.com` and `*.ghe.com` alike, ahead of the stored logins.

| Doppler config | Secrets | Effect |
| --- | --- | --- |
| `tools`/`gh` | `GH_TOKEN` (+ `GH_HOST`, default `github.com`) | logs in to `github.com` |
| `tools`/`ghe` | `GH_HOST` + `GH_TOKEN` | logs in to the enterprise host and writes its git credential helper (`~/.config/git/enterprise.gitconfig`) |
| `tools`/`ghe` | `GH_HOST` alone | writes the git config for a host you already logged in to by hand |
| `tools`/`ghe` | `GIT_USER_NAME`, `GIT_USER_EMAIL` | the git identity for repositories on the enterprise host (`~/.config/git/enterprise-identity.gitconfig`) |

If Doppler is not logged in or not reachable, the switch goes on with the logins
it already has and prints how to fix it. A fresh machine or sandbox therefore
needs only Doppler access for its first activation:

```sh
read -rs DOPPLER_TOKEN; export DOPPLER_TOKEN; nix run github:nothumancode/home
```

Over SSH, send a service account token that can read `tools`/`gh` and
`tools`/`ghe` (not your personal CLI token; a service token reaches only one config)
on stdin, to keep it out of shell history and the process list:

```sh
read -rs DOPPLER_TOKEN; printf '%s\n' "$DOPPLER_TOKEN" | ssh host \
  'read -r DOPPLER_TOKEN; export DOPPLER_TOKEN; nix run --refresh github:nothumancode/home'
```

After rotating a GitHub token in Doppler, run the switch again.
