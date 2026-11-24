{
  config,
  lib,
  pkgs,
  ...
}:

let
  dopplerBin = lib.getExe' pkgs.doppler "doppler";
  fnoxBin = lib.getExe' config.programs.fnox.package "fnox";
  ghBin = lib.getExe config.programs.gh.package;

  setupGithubAuth = pkgs.writeShellApplication {
    name = "setup-github-auth";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      export XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome}
      export GH_CONFIG_DIR=${lib.escapeShellArg "${config.xdg.configHome}/gh"}

      fnox_config="$XDG_CONFIG_HOME/fnox/config.toml"
      git_config_dir="$XDG_CONFIG_HOME/git"
      enterprise_git_config="$git_config_dir/enterprise.gitconfig"
      enterprise_identity_config="$git_config_dir/enterprise-identity.gitconfig"
      doppler_bin=${lib.escapeShellArg dopplerBin}
      fnox_bin=${lib.escapeShellArg fnoxBin}
      gh_bin=${lib.escapeShellArg ghBin}

      tmp_identity=""
      tmp_enterprise=""
      cleanup() {
        rm -f "$tmp_identity" "$tmp_enterprise"
      }
      trap cleanup EXIT

      if [[ ! -f "$fnox_config" ]]; then
        echo "setup-github-auth: fnox config not found at $fnox_config; skipping" >&2
        exit 0
      fi

      fnox_get() {
        "$fnox_bin" --config "$fnox_config" --no-daemon --non-interactive --if-missing error get "$1" 2>/dev/null
      }

      # Unset token env vars so gh reads/writes hosts.yml cleanly (required for *.ghe.com).
      gh_clean() {
        env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN \
          "$gh_bin" "$@"
      }

      doppler_token=""
      if ! doppler_token=$(fnox_get DOPPLER_TOKEN) || [[ -z "$doppler_token" ]]; then
        echo "setup-github-auth: unable to resolve DOPPLER_TOKEN via fnox; skipping token sync" >&2
        doppler_token=""
      fi

      doppler_get() {
        DOPPLER_TOKEN="$doppler_token" "$doppler_bin" secrets get "$1" -p vault -c prd --plain --no-check-version 2>/dev/null
      }

      sync_gh_token() {
        local hostname="$1"
        local secret_name="$2"
        local token current_token

        if [[ -z "$doppler_token" ]]; then
          return 1
        fi

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

      # Personal github.com authentication via Doppler.
      sync_gh_token "github.com" "GITHUB_TOKEN" || true

      # Enterprise host from fnox + token from Doppler.
      if ! host=$(fnox_get GITHUB_ENTERPRISE_HOST) || [[ -z "$host" ]]; then
        echo "setup-github-auth: unable to resolve GITHUB_ENTERPRISE_HOST via fnox; skipping enterprise setup" >&2
        exit 0
      fi

      host="''${host#https://}"
      host="''${host#http://}"
      host="''${host%/}"

      enterprise_token_changed=0
      if sync_gh_token "$host" "GITHUB_ENTERPRISE_TOKEN"; then
        enterprise_token_changed=1
      fi

      mkdir -p "$git_config_dir"

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
      git_protocol = "https";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  home.activation.setupGithubAuth = lib.mkIf config.programs.fnox.enable (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe setupGithubAuth}
    ''
  );
}
