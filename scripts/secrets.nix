{
  writeShellApplication,
  age,
  coreutils,
  git,
  gnugrep,
  gnused,
  jq,
  sops,
}:

writeShellApplication {
  name = "secrets";
  runtimeInputs = [
    age
    coreutils
    git
    gnugrep
    gnused
    jq
    sops
  ];
  text = builtins.readFile ./secrets.sh;
}
