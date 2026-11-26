{
  config,
  lib,
  pkgs,
  ...
}:

let
  dopplerBin = lib.getExe' pkgs.doppler "doppler";
  ghBin = lib.getExe config.programs.gh.package;

  setupGithubAuth = pkgs.writeShellApplication {
    name = "setup-github-auth";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.git
      pkgs.jq
    ];
    text = ''
      export XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome}
      export GH_CONFIG_DIR=${lib.escapeShellArg "${config.xdg.configHome}/gh"}

      git_config_dir="$XDG_CONFIG_HOME/git"
      enterprise_git_config="$git_config_dir/enterprise.gitconfig"
      enterprise_identity_config="$git_config_dir/enterprise-identity.gitconfig"
      doppler_bin=${lib.escapeShellArg dopplerBin}
      gh_bin=${lib.escapeShellArg ghBin}

      tmp_identity=""
      tmp_enterprise=""
      cleanup() {
        rm -f "$tmp_identity" "$tmp_enterprise"
      }
      trap cleanup EXIT

      # Unset token env vars so gh reads/writes hosts.yml cleanly (required for *.ghe.com).
      gh_clean() {
        env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN \
          "$gh_bin" "$@"
      }

      doppler_get() {
        "$doppler_bin" secrets get "$1" \
          -p ${lib.escapeShellArg config.doppler.project} -c ${lib.escapeShellArg config.doppler.config} \
          --plain --no-check-version 2>/dev/null
      }

      sync_gh_token() {
        local hostname="$1"
        local secret_name="$2"
        local token current_token

        if ! token=$(doppler_get "$secret_name") || [[ -z "$token" ]]; then
          echo "setup-github-auth: unable to fetch $secret_name from Doppler; skipping $hostname login" >&2
          return 1
        fi

        current_token=$(gh_clean auth token --hostname "$hostname" 2>/dev/null || true)
        if [[ "$current_token" == "$token" ]]; then
          return 1
        fi

        if ! printf '%s\n' "$token" | gh_clean auth login --hostname "$hostname" --git-protocol https --with-token; then
          echo "setup-github-auth: gh auth login failed for $hostname; continuing" >&2
          return 1
        fi

        return 0
      }

      mkdir -p "$git_config_dir"

      # Personal github.com authentication via Doppler.
      sync_gh_token "github.com" "GITHUB_TOKEN" || true

      # Enterprise host from environment or Doppler, token from Doppler.
      host="''${GITHUB_ENTERPRISE_HOST:-}"
      if [[ -z "$host" ]]; then
        host=$(doppler_get GITHUB_ENTERPRISE_HOST || true)
      fi

      if [[ -z "$host" ]]; then
        echo "setup-github-auth: GITHUB_ENTERPRISE_HOST not set in env or Doppler; skipping enterprise setup" >&2
        exit 0
      fi

      host="''${host#https://}"
      host="''${host#http://}"
      host="''${host%/}"

      enterprise_token_changed=0
      if sync_gh_token "$host" "GITHUB_ENTERPRISE_TOKEN"; then
        enterprise_token_changed=1
      fi

      if [[ "$enterprise_token_changed" -eq 1 || ! -s "$enterprise_identity_config" ]]; then
        if user_json=$(gh_clean api --hostname "$host" user 2>/dev/null); then
          enterprise_name=$(jq -r '.name // empty' <<<"$user_json")
          enterprise_email=$(jq -r '.email // empty' <<<"$user_json")

          if [[ -z "$enterprise_email" ]]; then
            enterprise_email=$(
              gh_clean api --hostname "$host" user/emails --jq '.[] | select(.primary) | .email' 2>/dev/null || true
            )
          fi

          enterprise_email="''${enterprise_email,,}"

          if [[ -n "$enterprise_name" || -n "$enterprise_email" ]]; then
            tmp_identity=$(mktemp "$git_config_dir/.enterprise-identity.XXXXXX")
            {
              echo "[user]"
              if [[ -n "$enterprise_name" ]]; then
                printf '\tname = %s\n' "$enterprise_name"
              fi
              if [[ -n "$enterprise_email" ]]; then
                printf '\temail = %s\n' "$enterprise_email"
              fi
            } >"$tmp_identity"
            chmod 600 "$tmp_identity"
            mv "$tmp_identity" "$enterprise_identity_config"
            tmp_identity=""
          fi
        fi
      fi

      tmp_enterprise=$(mktemp "$git_config_dir/.enterprise.XXXXXX")
      cat >"$tmp_enterprise" <<EOF
      [credential "https://$host"]
        helper =
        helper = !$gh_bin auth git-credential

      [credential "https://gist.$host"]
        helper =
        helper = !$gh_bin auth git-credential

      [includeIf "hasconfig:remote.*.url:https://$host/**"]
        path = $enterprise_identity_config

      [includeIf "hasconfig:remote.*.url:https://*@$host/**"]
        path = $enterprise_identity_config

      [includeIf "hasconfig:remote.*.url:ssh://git@$host/**"]
        path = $enterprise_identity_config

      [includeIf "hasconfig:remote.*.url:git@$host:*/**"]
        path = $enterprise_identity_config
      EOF
      chmod 600 "$tmp_enterprise"
      mv "$tmp_enterprise" "$enterprise_git_config"
      tmp_enterprise=""
    '';
  };
in
{
  programs.gh = {
    enable = true;

    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };

    settings = {
      editor = "nvim";
      git_protocol = "https";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
        pc = "pr create";
        prc = "pr checks";
        pv = "pr view";
        rv = "repo view";
      };
    };
  };

  # Network calls stay out of activation: the sync runs once per login session (and when
  # the script changes), not on every switch, image build, or headless activation.
  # After rotating a token: `systemctl --user restart setup-github-auth` or `setup-github-auth`.
  home.packages = [ setupGithubAuth ];

  systemd.user.services.setup-github-auth = {
    Unit.Description = "Sync GitHub and GitHub Enterprise logins from Doppler";
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe setupGithubAuth;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
