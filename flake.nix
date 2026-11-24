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
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
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

      checks = forAllSystems (
        pkgs:
        {
          style =
            pkgs.runCommand "lint"
              {
                nativeBuildInputs = with pkgs; [
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
                  ];
                };
              }
              ''
                cd "$src"
                find . -name '*.nix' -print0 | xargs -0 nixfmt --check
                statix check .
                deadnix --fail .
                stylua --check modules/neovim
                touch "$out"
              '';
        }
        // lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
          home = self.homeConfigurations."rodat".activationPackage;
        }
      );

      homeConfigurations."rodat" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor "x86_64-linux";
        modules = [ ./home.nix ];
        extraSpecialArgs = { inherit inputs; };
      };
    };
}
