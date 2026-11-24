{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.brain;
in
{
  programs.brain.enable = true;

  # Agent hooks live in files the agents and other tools also write, so they are not declared
  # in Nix: programs.brain.enable*Integration would make Home Manager reset those hook lists on
  # every switch. Instead brain sets itself up in place once the generation is linked. The
  # command is its own check: it compares what is there with what it would write, touches only
  # its own entries, and writes nothing when they are current (so a switch that does not
  # change brain is a no-op, and a hook something else removed comes back).
  # Never add --service here: the watcher is the systemd unit programs.brain already manages.
  home.activation.brainAgentIntegrations =
    lib.hm.dag.entryAfter
      [
        "writeBoundary"
        "claudeCodeSettings"
        "codexMutableSettings"
      ]
      ''
        run env PATH="${cfg.package}/bin:$PATH" ${lib.getExe cfg.package} install --quiet --claude --codex --pi \
          || warnEcho "brain: an agent integration is not set up; see the lines above"
      '';
}
