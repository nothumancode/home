# Home

Two ways to install Tomas's development environment. **Choose one per home directory**: both configure the same Git, shell, editor, and agent files.

| App | Choose it for | Start here |
| --- | --- | --- |
| **[Nix](nix/README.md)** | A locked Home Manager generation, user services, remote switches and rollbacks. | `nix run --refresh github:nothumancode/home`, or `hm-switch` from a local installation. |
| **[Mise](mise/README.md)** | Per-user tools and dotfiles without Nix or Home Manager. | `mise bootstrap --from https://github.com/nothumancode/home.git --from-dir ~/.dotfiles --config-dir mise` |

The root `flake.nix` and `flake.lock` are the single public Nix entry point; the implementation lives under `nix/`. Mise has its own [global profile](mise/config.toml). Both apps consume [shared settings](shared/), including the Git identity, agent defaults and Neovim configuration.

## Sandboxes

See the [sandbox setup](nix/README.md#sandboxes) for the `rodat` home and platforms that run as root.

### Modal

See the [Modal guide](nix/README.md#modal) for `modal-sandbox`.

## Deploy with Cachix

Follow [agent enrollment and deployment](nix/README.md#deploy-with-cachix). The Nix workflow deploys only on a manual `main` run with an agent selected.
