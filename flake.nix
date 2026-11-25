{
  description = "Home Manager configuration of rodat";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    wit.url = "github:thehumanworks/wit";
    capnshell.url = "github:thehumanworks/capnshell";
    twg.url = "github:thehumanworks/twg-nix";
    kbtd.url = "github:thehumanworks/kbtd";
    brain.url = "github:thehumanworks/brain";
  };

  outputs = inputs: import ./nix/outputs.nix inputs;
}
