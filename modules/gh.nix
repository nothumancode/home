{
  config,
  lib,
  pkgs,
  ...
}:

let
  ghBin = lib.getExe config.programs.gh.package;

  # Logs gh in only from credentials passed to the switch; it never fetches them itself.
  setupGithubAuth = pkgs.writeShellApplication {
    name = "setup-github-auth";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      export GH_CONFIG_DIR=${lib.escapeShellArg "${config.xdg.configHome}/gh"}

      git_config_dir=${lib.escapeShellArg "${config.xdg.configHome}/git"}
      enterprise_git_config="$git_config_dir/enterprise.gitconfig"
      enterprise_identity_config="$git_config_dir/enterprise-identity.gitconfig"
      gh_bin=${lib.escapeShellArg ghBin}

      tmp=""
      trap 'rm -f "$tmp"' EXIT

      # Token env vars would shadow the stored login and make gh refuse to store a new one.
      gh_clean() {
        env -u GH_TOKEN -u GITHUB_TOKEN -u GH_ENTERPRISE_TOKEN -u GITHUB_ENTERPRISE_TOKEN -u GH_HOST \
          "$gh_bin" "$@"
      }

      warn() {
        printf 'setup-github-auth: %s\n' "$1" >&2
        shift
        printf '  %s\n' "$@" >&2
      }

      strip_host() {
        local host="''${1#https://}"
        host="''${host#http://}"
        printf '%s' "''${host%/}"
      }

      logged_in() {
        gh_clean auth token --hostname "$1" >/dev/null 2>&1
      }

      # Sets token_changed=1 when it stores a new token; fails when gh rejects it.
      token_changed=0
      login() {
        local host="$1" token="$2"
        if [[ "$(gh_clean auth token --hostname "$host" 2>/dev/null || true)" == "$token" ]]; then
          echo "setup-github-auth: $host login is current"
          return 0
        fi
        if ! printf '%s\n' "$token" | gh_clean auth login --hostname "$host" --git-protocol https --with-token; then
          warn "gh rejected the token for $host; it stays logged out." \
            "Check the token, then rerun the switch with it set."
          return 1
        fi
        echo "setup-github-auth: logged in to $host"
        token_changed=1
      }

      # github.com, or another host named by GH_HOST.
      host=$(strip_host "''${GH_HOST:-github.com}")
      if [[ -n "''${GH_TOKEN:-}" ]]; then
        login "$host" "$GH_TOKEN" || true
      elif ! logged_in "$host"; then
        warn "$host has no login, and GH_TOKEN is not set." \
          "Rerun the switch with the token:  read -rs GH_TOKEN; GH_TOKEN=\$GH_TOKEN hm-switch" \
          "Or log in by hand:                gh auth login --hostname $host --git-protocol https"
      fi

      host=$(strip_host "''${GH_ENTERPRISE_HOST:-}")
      if [[ -z "$host" ]]; then
        if [[ -n "''${GH_ENTERPRISE_TOKEN:-}" ]]; then
          warn "GH_ENTERPRISE_TOKEN is set without GH_ENTERPRISE_HOST; skipping GitHub Enterprise." \
            "Rerun the switch with both set."
        elif [[ ! -s "$enterprise_git_config" ]]; then
          warn "GitHub Enterprise is not set up, and GH_ENTERPRISE_HOST/GH_ENTERPRISE_TOKEN are not set." \
            "Rerun the switch with both:  read -rs GH_ENTERPRISE_TOKEN; GH_ENTERPRISE_HOST=<host> GH_ENTERPRISE_TOKEN=\$GH_ENTERPRISE_TOKEN hm-switch" \
            "Or log in by hand:          gh auth login --hostname <host> --git-protocol https" \
            "  then rerun with the host: GH_ENTERPRISE_HOST=<host> hm-switch"
        fi
        exit 0
      fi

      if [[ -n "''${GH_ENTERPRISE_TOKEN:-}" ]]; then
        login "$host" "$GH_ENTERPRISE_TOKEN" || exit 0
      elif ! logged_in "$host"; then
        warn "$host has no login, and GH_ENTERPRISE_TOKEN is not set." \
          "Rerun the switch with the token:  read -rs GH_ENTERPRISE_TOKEN; GH_ENTERPRISE_TOKEN=\$GH_ENTERPRISE_TOKEN GH_ENTERPRISE_HOST=$host hm-switch" \
          "Or log in by hand:                gh auth login --hostname $host --git-protocol https"
        exit 0
      fi

      mkdir -p "$git_config_dir"

      # The work identity comes from the enterprise account; it is fetched again only
      # when the token changes or the file is missing.
      if [[ "$token_changed" -eq 1 || ! -s "$enterprise_identity_config" ]]; then
        if user_json=$(gh_clean api --hostname "$host" user 2>/dev/null); then
          name=$(jq -r '.name // empty' <<<"$user_json")
          email=$(jq -r '.email // empty' <<<"$user_json")
          if [[ -z "$email" ]]; then
            email=$(gh_clean api --hostname "$host" user/emails --jq '.[] | select(.primary) | .email' 2>/dev/null || true)
          fi
          email="''${email,,}"
          if [[ -n "$name" || -n "$email" ]]; then
            tmp=$(mktemp "$git_config_dir/.enterprise-identity.XXXXXX")
            {
              echo "[user]"
              [[ -z "$name" ]] || printf '\tname = %s\n' "$name"
              [[ -z "$email" ]] || printf '\temail = %s\n' "$email"
            } >"$tmp"
            chmod 600 "$tmp"
            mv "$tmp" "$enterprise_identity_config"
          fi
        else
          warn "could not read your $host profile; git keeps the default identity there."
        fi
      fi

      tmp=$(mktemp "$git_config_dir/.enterprise.XXXXXX")
      cat >"$tmp" <<EOF
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
      chmod 600 "$tmp"
      mv "$tmp" "$enterprise_git_config"
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

  # GitHub logins come only from GH_TOKEN (for GH_HOST, default github.com) and
  # GH_ENTERPRISE_TOKEN + GH_ENTERPRISE_HOST passed to the switch. Without them it makes
  # no network call and warns, with the manual steps, about hosts that are not set up.
  home.activation.setupGithubAuth = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe setupGithubAuth} || warnEcho "GitHub login setup failed; the switch continues without it."
  '';
}
