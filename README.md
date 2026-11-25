# Home

Two ways to install Tomas's development environment. **Choose one per home directory**: both configure the same Git, shell, editor, and agent files.

| App | Choose it for | Start here |
| --- | --- | --- |
| **[Nix](nix/README.md)** | A locked Home Manager generation, user services, remote switches and rollbacks. | `nix run --refresh github:nothumancode/home`, or `hm-switch` from a local installation. |
| **[Mise](mise/README.md)** | Per-user tools and ordinary dotfiles on a Linux host without Nix, a daemon, or Home Manager. | Install Mise, run `./mise/setup`, then `cd ~ && ~/.local/bin/mise install`. |

The root `flake.nix` and `flake.lock` are the single public Nix entry point; the implementation lives under `nix/`. Mise has its own [global profile](mise/config.toml). Both apps consume [shared settings](shared/), including the Git identity, agent defaults and Neovim configuration.
