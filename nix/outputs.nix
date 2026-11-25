inputs@{
  self,
  nixpkgs,
  home-manager,
  ...
}:
let
  inherit (nixpkgs) lib;
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
  remoteFlake = "github:nothumancode/home";
  cachixConfig = {
    substituters = [
      "https://thehuman.cachix.org"
      "https://nixpkgs-python.cachix.org"
    ];
    publicKeys = [
      "thehuman.cachix.org-1:5e++Y7TlcHLBOmHnqv1bmgUp0QuFJn+XCzN/V0Y5/6w="
      "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
    ];
  };
  allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "twg"
    ];
  pkgsFor =
    system:
    import nixpkgs {
      inherit system;
      config = { inherit allowUnfreePredicate; };
    };
  forAllSystems = fn: lib.genAttrs systems (system: fn (pkgsFor system));

  # One account everywhere. `home-manager switch --flake` and `nh home switch` select
  # homeConfigurations.$USER; sandboxes with another user alias it (see README).
  username = "rodat";

  # Machines running a Cachix Deploy agent. The agent names itself after the hostname
  # (modules/cachix-deploy.nix), and every machine gets the same generation.
  deployHosts = [ "LT-POR-02056" ];

  # Keep the activation package as a store reference so pushing the spec pushes its closure.
  cachixDeploy = (pkgsFor "x86_64-linux").writeText "cachix-deploy.json" (
    builtins.toJSON {
      agents = lib.genAttrs deployHosts (_: self.homeConfigurations.${username}.activationPackage);
    }
  );

  # `nix run <flake>`: switch $USER to this exact flake revision (no checkout needed).
  hmRemoteSwitch =
    let
      pkgs = pkgsFor "x86_64-linux";
    in
    pkgs.writeShellApplication {
      name = "hm-remote-switch";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.nh
      ];
      text = ''
        export USER="''${USER:-$(id -un)}"

        # Home Manager needs a Nix profile directory, and a fresh account has none
        # until its first nix-env/nix profile call.
        mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles"

        # Whoever can write the store (root, or the owner of a single-user install) can
        # trust the caches itself. Everyone else relies on /etc/nix (see nix/README.md); Nix
        # warns and builds locally when they are not trusted there.
        caches="extra-substituters = ${toString cachixConfig.substituters}"
        if [[ -w /nix/var/nix/db ]]; then
          caches+=$'\n'"extra-trusted-public-keys = ${toString cachixConfig.publicKeys}"
        fi
        export NIX_CONFIG="''${NIX_CONFIG:-}"$'\n'"$caches"

        exec nh home switch -b backup "path:${self}" "$@"
      '';
    };
in
{
  formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

  devShells = forAllSystems (pkgs: {
    default = pkgs.mkShellNoCC {
      packages = with pkgs; [
        actionlint
        deadnix
        nixfmt
        nixfmt-tree
        shellcheck
        shfmt
        statix
        stylua
      ];
    };
  });

  apps.x86_64-linux.default = {
    type = "app";
    program = lib.getExe hmRemoteSwitch;
  };

  packages.x86_64-linux = {
    cachix-deploy = cachixDeploy;
    default = cachixDeploy;
  };

  checks = forAllSystems (
    pkgs:
    {
      style =
        pkgs.runCommand "lint"
          {
            nativeBuildInputs = with pkgs; [
              actionlint
              deadnix
              findutils
              nixfmt
              statix
              stylua
            ];
            src = lib.fileset.toSource {
              root = ../.;
              fileset = lib.fileset.unions [
                ../flake.nix
                ./.
                ../shared
                ../mise/config/nvim
                (lib.fileset.maybeMissing ../.github)
              ];
            };
          }
          ''
            cd "$src"
            find . -name '*.nix' -print0 | xargs -0 nixfmt --check
            statix check .
            deadnix --fail .
            stylua --no-editorconfig --check nix/modules/neovim shared/nvim mise/config/nvim
            if [[ -d .github/workflows ]]; then
              find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -exec actionlint {} +
            fi
            touch "$out"
          '';
    }
    // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
      remote-switch = hmRemoteSwitch;
      cachix-deploy = cachixDeploy;
      home = self.homeConfigurations.${username}.activationPackage;
    }
  );

  homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
    pkgs = pkgsFor "x86_64-linux";
    modules = [
      ./home.nix
      {
        home = {
          inherit username;
          homeDirectory = "/home/${username}";
        };
      }
    ];
    extraSpecialArgs = {
      inherit cachixConfig inputs remoteFlake;
    };
  };
}
