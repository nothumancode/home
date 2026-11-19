{
  description = "Home Manager configuration for Linux, WSL and macOS";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      inherit (nixpkgs) lib;

      # Account names this configuration is used under. Each name works on
      # every system below; the home directory follows the platform.
      users = [
        "rodat"
        "tomas"
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }
          )
        );

      mkHome =
        pkgs: username:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home.nix
            {
              home = {
                inherit username;
                homeDirectory = (if pkgs.stdenv.hostPlatform.isDarwin then "/Users/" else "/home/") + username;
              };
            }
          ];
        };
    in
    {
      # Nix resolves `.#homeConfigurations.<user>` through legacyPackages.<current
      # system>, so `home-manager switch --flake .` selects the right platform
      # without a table of hosts.
      legacyPackages = forAllSystems (pkgs: {
        homeConfigurations = lib.genAttrs users (mkHome pkgs);
      });

      packages = forAllSystems (pkgs: {
        # Both are used by bootstrap.sh before the first activation.
        home-manager = home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default;
        secrets = pkgs.callPackage ./scripts/secrets.nix { };
      });

      checks = forAllSystems (pkgs: {
        home = (mkHome pkgs (lib.head users)).activationPackage;
        bootstrap = pkgs.runCommand "check-bootstrap" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
          shellcheck ${./bootstrap.sh}
          touch $out
        '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
