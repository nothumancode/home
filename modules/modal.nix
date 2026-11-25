{ pkgs, ... }:
let
  modalSandbox = pkgs.writeShellApplication {
    name = "modal-sandbox";
    runtimeInputs = with pkgs; [
      python3
      (python3.withPackages (
        ps: with ps; [
          modal
        ]
      ))
    ];
    text = ''
      import
    '';
  };
in
{
  home.packages = [
    pkgs.python313
    pkgs.python313Packages.modal
  ];
}
