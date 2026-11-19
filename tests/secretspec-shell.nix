{ pkgs }:

let
  # No network, identity, or real declaration is used by this check.
  fixture = pkgs.writeTextDir "home-manager/secretspec.toml" ''
    [project]
    name = "home-manager-test"
    revision = "1.0"

    [profiles.default]
    HM_TEST_REQUIRED = { description = "test input", providers = ["env"] }
    HM_TEST_MARKER = { description = "test output", providers = ["env"], default = "fixture only" }
  '';
  hooks = import ../modules/secretspec.nix {
    inherit pkgs;
    inherit (pkgs) lib;
    config.xdg.configHome = fixture;
  };
  check = shell: init: ''
    ${shell} -eu -c '
      export HM_TEST_REQUIRED=present
      set -vx
      . "$1"
      set +vx
      test "$(printenv HM_TEST_MARKER)" = "fixture only"

      unset HM_TEST_REQUIRED HM_TEST_MARKER
      . "$1" 2>missing.err
      test ! -s missing.err
      test -z "''${HM_TEST_MARKER+x}"
    ' _ ${pkgs.writeText "test-shell-init" init} >stdout 2>trace
    test ! -s stdout
    if grep -Fq 'fixture only' trace; then exit 1; fi
  '';
in
pkgs.runCommand "check-secretspec-shell" { } ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"
  cd "$HOME"
  ${check "${pkgs.bash}/bin/bash" hooks.programs.bash.initExtra}
  ${check "${pkgs.zsh}/bin/zsh" hooks.programs.zsh.initContent}
  touch "$out"
''
