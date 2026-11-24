{
  description = "Home Manager configuration of rodat";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    capnshell.url = "github:thehumanworks/capnshell";
    twg.url = "github:thehumanworks/twg-nix";
    kbtd.url = "github:thehumanworks/kbtd";
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
      users = {
        rodat = "/home/rodat";
        root = "/root";
        tomas = "/home/tomas";
      };
      cachixConfig = {
        substituters = [
          "https://thehuman.cachix.org"
          "https://nixpkgs-python.cachix.org"
        ];
        publicKeys = [
          "thehuman.cachix.org-1:5e++Y7TlcHLBOmHnqv1bmgUp0QuFJn+XCzN/V0Y5/6w="
          "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
        ];
        # Populates the bash array nix_opts with Cachix substituters/keys (when trusted)
        # and a GitHub access token (when available) so remote switches avoid local rebuilds
        # and anonymous GitHub API rate limits.
        nixOptsShellSnippet = ''
          substituter_list=(
            ${lib.concatMapStringsSep "\n  " lib.escapeShellArg cachixConfig.substituters}
          )
          public_key_list=(
            ${lib.concatMapStringsSep "\n  " lib.escapeShellArg cachixConfig.publicKeys}
          )
          substituters="''${substituter_list[*]}"
          public_keys="''${public_key_list[*]}"

          nix_opts=()

          trusted_keys="$(nix config show trusted-public-keys 2>/dev/null || true)"
          trusted_subs="$(nix config show trusted-substituters 2>/dev/null || true)"
          configured_subs="$(nix config show substituters 2>/dev/null || true)"

          cache_trusted=true
          for key in "''${public_key_list[@]}"; do
            if [[ " $trusted_keys " != *" $key "* ]]; then
              cache_trusted=false
              break
            fi
          done
          for sub in "''${substituter_list[@]}"; do
            if [[ " $trusted_subs $configured_subs " != *" $sub "* && " $trusted_subs $configured_subs " != *" $sub/ "* ]]; then
              cache_trusted=false
              break
            fi
          done

          if [[ "$cache_trusted" == true ]]; then
            nix_opts+=(--option extra-substituters "$substituters")
          else
            user_trusted=false
            if [[ "$(id -u)" -eq 0 ]]; then
              user_trusted=true
            elif info_json="$(nix store info --json 2>/dev/null || nix store ping --json 2>/dev/null)"; then
              if jq -e '.trusted == true or .trusted == 1 or .url != "daemon"' <<<"$info_json" >/dev/null 2>&1; then
                user_trusted=true
              fi
            fi

            if [[ "$user_trusted" == true ]]; then
              nix_opts+=(
                --option extra-substituters "$substituters"
                --option extra-trusted-public-keys "$public_keys"
              )
            else
              current_user="$(id -un)"
              cat >&2 <<EOF
          warning: Cachix caches are not trusted by the Nix daemon and '$current_user' is not a trusted Nix user.
          To enable Cachix on this machine, run once with sudo:
            sudo tee -a /etc/nix/nix.custom.conf <<'NIXCONF'
          extra-trusted-substituters = $substituters
          extra-trusted-public-keys = $public_keys
          NIXCONF
            sudo systemctl restart nix-daemon
          Continuing without Cachix (packages not on cache.nixos.org will build locally)...
          EOF
            fi
          fi

          access_tokens="$(nix config show access-tokens 2>/dev/null || true)"
          if [[ "$access_tokens" != *"github.com="* ]]; then
            gh_token="''${GITHUB_TOKEN:-''${GH_TOKEN:-}}"
            if [[ -z "$gh_token" ]] && command -v gh >/dev/null 2>&1; then
              gh_token="$(gh auth token --hostname github.com 2>/dev/null || true)"
            fi
            if [[ -n "$gh_token" ]]; then
              nix_opts+=(--option access-tokens "github.com=$gh_token")
            fi
          fi
        '';
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

      mkHome =
        {
          system ? "x86_64-linux",
          username,
          homeDirectory,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            ./home.nix
            {
              home = {
                inherit username homeDirectory;
              };
            }
          ];
          extraSpecialArgs = {
            inherit cachixConfig inputs remoteFlake;
          };
        };

      hmRemoteSwitch =
        let
          pkgs = pkgsFor "x86_64-linux";
          userNames = builtins.attrNames users;
        in
        pkgs.writeShellApplication {
          name = "hm-remote-switch";
          runtimeInputs = [
            home-manager.packages.x86_64-linux.default
            pkgs.coreutils
            pkgs.jq
            pkgs.nvd
          ];
          text = ''
            target="$(id -un)"
            args=()
            while [[ $# -gt 0 ]]; do
              case "$1" in
                --user)
                  if [[ $# -lt 2 ]]; then
                    echo "hm-remote-switch: --user requires a value" >&2
                    exit 1
                  fi
                  target="$2"
                  shift 2
                  ;;
                *)
                  args+=("$1")
                  shift
                  ;;
              esac
            done

            case "$target" in
              ${lib.concatStringsSep " | " userNames}) ;;
              *)
                echo "hm-remote-switch: unsupported user '$target' (available: ${lib.concatStringsSep ", " userNames})" >&2
                echo "Pass --user <name> to select one explicitly." >&2
                exit 1
                ;;
            esac

            ${cachixConfig.nixOptsShellSnippet}

            profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
            old_gen=""
            if [[ -e "$profile" ]]; then
              old_gen=$(readlink -f "$profile" || true)
            fi

            home-manager switch -b backup --no-write-lock-file \
              --flake "path:${self}#''${target}" \
              "''${nix_opts[@]}" "''${args[@]}"

            new_gen=""
            if [[ -e "$profile" ]]; then
              new_gen=$(readlink -f "$profile" || true)
            fi

            if [[ -n "$old_gen" && -n "$new_gen" && "$old_gen" != "$new_gen" ]]; then
              nvd diff "$old_gen" "$new_gen" || true
            fi
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
                  actionlint
                fi
                touch "$out"
              '';
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
          lib.mapAttrs' (
            username: cfg: lib.nameValuePair "home-${username}" cfg.activationPackage
          ) self.homeConfigurations
          // {
            remote-switch = hmRemoteSwitch;
          }
        )
      );

      homeConfigurations = lib.mapAttrs (
        username: homeDirectory:
        mkHome {
          inherit username homeDirectory;
        }
      ) users;
    };
}
