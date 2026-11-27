{
  config,
  lib,
  pkgs,
  ...
}:

let
  ghBin = lib.getExe config.programs.gh.package;
  doppler = lib.getExe pkgs.doppler;

  # Logs gh in from two Doppler configs, one per host, each holding gh's own names:
  # tools/gh (github.com) and tools/ghe (GitHub Enterprise, with its git credential
  # helper and the work identity from GIT_USER_*). Uses whatever Doppler auth the user
  # has (`doppler login` or DOPPLER_TOKEN); without it, it warns and changes nothing.
  setupGithubAuth = pkgs.writeShellApplication {
    name = "setup-github-auth";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      config.programs.git.package
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
        if (($#)); then
          printf '  %s\n' "$@" >&2
        fi
      }

      strip_host() {
        local host="''${1#https://}"
        host="''${host#http://}"
        printf '%s' "''${host%/}"
      }

      logged_in() {
        gh_clean auth token --hostname "$1" >/dev/null 2>&1
      }

      # Fails when gh rejects the token.
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
      }

      if [[ -z "''${DOPPLER_TOKEN:-}" && -z "$(${doppler} configure get token --plain 2>/dev/null)" ]]; then
        warn "no Doppler login; GitHub logins are unchanged." \
          "Log in with 'doppler login' or set DOPPLER_TOKEN, then rerun the switch."
        exit 0
      fi

      # Prints one config's GH_HOST, GH_TOKEN and GIT_USER_* as JSON. Only Doppler's
      # values count, not copies already in the switch environment. One attempt and no
      # fallback file: offline, the switch moves on quickly and no extra copy of the
      # secrets lands on disk.
      unset GH_HOST GH_TOKEN GIT_USER_NAME GIT_USER_EMAIL
      read_config() {
        if ! ${doppler} run --project tools --config "$1" \
          --no-fallback --no-check-version --attempts 1 \
          --only-secrets GH_HOST --only-secrets GH_TOKEN \
          --only-secrets GIT_USER_NAME --only-secrets GIT_USER_EMAIL \
          --no-exit-on-missing-only-secrets \
          -- jq -n 'env | {GH_HOST, GH_TOKEN, GIT_USER_NAME, GIT_USER_EMAIL}'; then
          warn "could not read tools/$1 from Doppler; its GitHub login is unchanged."
          return 1
        fi
      }
      field() {
        jq -r --arg name "$2" '.[$name] // empty' <<<"$1"
      }

      if secrets=$(read_config gh); then
        host=$(strip_host "$(field "$secrets" GH_HOST)")
        host="''${host:-github.com}"
        token=$(field "$secrets" GH_TOKEN)
        if [[ -n "$token" ]]; then
          login "$host" "$token" || true
        elif ! logged_in "$host"; then
          warn "$host has no login, and tools/gh has no GH_TOKEN." \
            "Add GH_TOKEN to tools/gh and rerun the switch, or log in by hand:" \
            "  gh auth login --hostname $host --git-protocol https"
        fi
      fi

      secrets=$(read_config ghe) || exit 0
      host=$(strip_host "$(field "$secrets" GH_HOST)")
      token=$(field "$secrets" GH_TOKEN)
      if [[ -z "$host" ]]; then
        if [[ -n "$token" ]]; then
          warn "tools/ghe has GH_TOKEN but no GH_HOST; skipping GitHub Enterprise."
        fi
        exit 0
      fi

      if [[ -n "$token" ]]; then
        login "$host" "$token" || exit 0
      elif ! logged_in "$host"; then
        warn "$host has no login, and tools/ghe has no GH_TOKEN." \
          "Add GH_TOKEN to tools/ghe and rerun the switch, or log in by hand:" \
          "  gh auth login --hostname $host --git-protocol https"
        exit 0
      fi

      mkdir -p "$git_config_dir"

      # The work identity for repositories on the enterprise host. git config writes the
      # values with the quoting they need.
      name=$(field "$secrets" GIT_USER_NAME)
      email=$(field "$secrets" GIT_USER_EMAIL)
      if [[ -n "$name" || -n "$email" ]]; then
        tmp=$(mktemp "$git_config_dir/.enterprise-identity.XXXXXX")
        [[ -z "$name" ]] || git config --file "$tmp" user.name "$name"
        [[ -z "$email" ]] || git config --file "$tmp" user.email "''${email,,}"
        chmod 600 "$tmp"
        mv "$tmp" "$enterprise_identity_config"
      elif [[ ! -s "$enterprise_identity_config" ]]; then
        warn "tools/ghe has no GIT_USER_NAME or GIT_USER_EMAIL;" \
          "commits in $host repositories use the default identity."
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

  # Two Doppler calls per switch (none on dry runs); it never fails the switch.
  home.activation.setupGithubAuth = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${lib.getExe setupGithubAuth} || warnEcho "GitHub login setup failed; the switch continues without it."
  '';
}
