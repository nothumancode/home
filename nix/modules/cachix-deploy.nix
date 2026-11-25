{ config, ... }:

let
  cfg = config.services.cachix-agent;
in
{
  services.cachix-agent = {
    enable = true;
    # systemd expands %H to the hostname, so one generation serves every machine.
    name = "%H";
    # Cachix looks a bare profile name up under /nix/var/nix/profiles/per-user, which Home
    # Manager no longer uses; give it the real profile so it knows what to roll back to.
    profile = "${config.xdg.stateHome}/nix/profiles/home-manager";
  };

  # Enrollment is the token file (`CACHIX_AGENT_TOKEN=...`): no file, no agent.
  systemd.user.services.cachix-agent.Unit.ConditionPathExists = cfg.credentialsFile;
}
