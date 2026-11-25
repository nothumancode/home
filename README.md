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

## Deploy with Cachix

Cachix Deploy pushes a built generation to long-lived machines; each runs an
agent named after its hostname. Use a Cachix workspace backed by the `thehuman`
binary cache.

### Enroll a machine once

1. Add its hostname to `deployHosts` in [flake.nix](flake.nix).
2. On the machine, as `rodat`, store the workspace's agent token and switch:

   ```sh
   (umask 077; printf 'CACHIX_AGENT_TOKEN=%s\n' "$(fnox --if-missing error get CACHIX_AGENT_TOKEN)" \
     > ~/.config/cachix-agent.token)
   hm-switch
   journalctl --user -u cachix-agent.service -n 20
   ```

   Look for **Agent registered.** On a multi-user Nix install, trust the cache
   in the Nix daemon first (see [AGENTS.md](AGENTS.md)).
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
