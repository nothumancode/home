{
  description = "Home Manager configuration of rodat";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    capnshell.url = "github:thehumanworks/capnshell";
    twg.url = "github:thehumanworks/twg-nix";
    kbtd.url = "github:thehumanworks/kbtd";
    brain.url = "github:thehumanworks/brain";
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
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
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

      # `home-manager switch --flake` and `nh home switch` select homeConfigurations.$USER.
      users = [
        "rodat"
        "root"
        "tomas"
      ];

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

            # Unprivileged users rely on the caches being trusted in /etc/nix (see AGENTS.md);
            # Nix warns and builds locally when they are not.
            caches="extra-substituters = ${toString cachixConfig.substituters}"
            if [[ "$(id -u)" -eq 0 ]]; then
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
                  root = ./.;
                  fileset = lib.fileset.unions [
                    ./flake.nix
                    ./home.nix
                    ./modules
                    (lib.fileset.maybeMissing ./.github)
                  ];
                };
              }
              ''
                cd "$src"
                find . -name '*.nix' -print0 | xargs -0 nixfmt --check
                statix check .
                deadnix --fail .
                stylua --no-editorconfig --check modules/neovim
                if [[ -d .github/workflows ]]; then
                  find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) -exec actionlint {} +
                fi
                touch "$out"
              '';
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          remote-switch = hmRemoteSwitch;
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
          lib.mapAttrs' (
            user: hm: lib.nameValuePair "home-${user}" hm.activationPackage
          ) self.homeConfigurations
        )
      );

      homeConfigurations = lib.genAttrs users (
        username:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-linux";
          modules = [
            ./home.nix
            {
              home = {
                inherit username;
                homeDirectory = if username == "root" then "/root" else "/home/${username}";
              };
            }
          ];
          extraSpecialArgs = {
            inherit cachixConfig inputs remoteFlake;
          };
        }
      );
    };
}
