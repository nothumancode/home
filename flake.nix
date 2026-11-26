{
  description = "Home Manager configuration of rodat";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Our own flakes build against this nixpkgs, so the profile carries one runtime
    # stack instead of one per input. CI builds them and pushes to the thehuman cache.
    wit = {
      url = "github:thehumanworks/wit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    capnshell = {
      url = "github:thehumanworks/capnshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    twg = {
      url = "github:thehumanworks/twg-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    kbtd = {
      url = "github:thehumanworks/kbtd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    brain = {
      url = "github:thehumanworks/brain";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # The only system with a Home Manager configuration. Add outputs for another
      # system only together with a configuration that builds there.
      system = "x86_64-linux";
      remoteFlake = "github:thehumanworks/home";
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

      # Unfree packages allowed by name; home.nix mirrors the list for impure nixpkgs use.
      unfreePackages = [
        "claude-code"
        "twg"
      ];

      # One nixpkgs instance for every output.
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreePackages;
      };

      # One account everywhere. `home-manager switch --flake` and `nh home switch` select
      # homeConfigurations.$USER; sandboxes with another user alias it (see README).
      username = "rodat";

      # The single formatter behind `nix fmt`, hm-fmt, hm-check and checks.style.
      treefmt = pkgs.nixfmt-tree.override {
        runtimeInputs = with pkgs; [
          deadnix
          stylua
        ];
        settings = {
          on-unmatched = "debug";
          formatter = {
            deadnix = {
              command = "deadnix";
              options = [ "--edit" ];
              includes = [ "*.nix" ];
            };
            stylua = {
              command = "stylua";
              options = [ "--no-editorconfig" ];
              includes = [ "*.lua" ];
            };
          };
        };
      };

      # `nix run <flake>`: switch $USER to this exact flake revision (no checkout needed).
      hmRemoteSwitch = pkgs.writeShellApplication {
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
          # trust the caches itself. Everyone else relies on /etc/nix (see AGENTS.md); Nix
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
      formatter.${system} = treefmt;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          treefmt
          pkgs.actionlint
          pkgs.shellcheck
          pkgs.statix
        ];
      };

      apps.${system}.default = {
        type = "app";
        program = lib.getExe hmRemoteSwitch;
      };

      checks.${system} = {
        style =
          pkgs.runCommand "style"
            {
              nativeBuildInputs = [
                treefmt
                pkgs.actionlint
                pkgs.statix
              ];
              src = lib.fileset.toSource {
                root = ./.;
                fileset = lib.fileset.unions [
                  ./flake.nix
                  ./home.nix
                  ./modules
                  ./.github
                ];
              };
            }
            ''
              cp -r "$src" tree
              chmod -R u+w tree
              cd tree
              HOME="$TMPDIR" treefmt --ci --tree-root .
              statix check .
              actionlint .github/workflows/*.yml
              touch "$out"
            '';
        remote-switch = hmRemoteSwitch;
        home = self.homeConfigurations.${username}.activationPackage;
      };

      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
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
          inherit
            cachixConfig
            inputs
            remoteFlake
            unfreePackages
            ;
        };
      };
    };
}
