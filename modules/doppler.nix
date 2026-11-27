{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.doppler;
  doppler = lib.getExe pkgs.doppler;

  # A launcher that runs `run` under `doppler run` with the secrets of one Doppler config
  # (all of them, or only `secrets` when listed). Without Doppler auth it runs `program`
  # without them, so a tool's own stored login still works.
  mkLauncher =
    {
      name,
      project,
      config,
      program,
      run ? program,
      secrets ? [ ],
    }:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        doppler=${doppler}
        if [[ -z "''${DOPPLER_TOKEN:-}" && -z "$("$doppler" configure get token --plain 2>/dev/null)" ]]; then
          echo "${name}: no Doppler login; starting without ${project}/${config} secrets" >&2
          exec ${program} "$@"
        fi
        exec "$doppler" run \
          --project ${lib.escapeShellArg project} \
          --config ${lib.escapeShellArg config} \
          ${lib.concatMapStringsSep " " (secret: "--only-secrets ${lib.escapeShellArg secret}") secrets} \
          -- ${run} "$@"
      '';
    };

  # Merges a credentials file with the Doppler copy. Inputs come from the environment,
  # never argv: LOCAL (the file), REMOTE (the Doppler secret, maybe empty) and, for `push`,
  # BASE (the file as synced before the program ran). Prints {error} or the result.
  mergeCredentials = pkgs.writeText "merge-credentials.jq" ''
    def fail($why): error("sync: \($why)");
    def parse($what):
      (if test("^\\s*$") then {} else (try fromjson catch null) end)
      | if type == "object" then . else fail("\($what) is not a JSON object") end;

    # The file as credentials by name: with $entries each entry is one (Pi: one per provider),
    # otherwise the whole file is a single credential (Codex).
    def split($what):
      if $entries then
        (if all(.[]; type == "object") then . else fail("\($what) is not an object of credentials") end)
      elif . == {} then {}
      else { "": . } end;
    def join: if $entries then . else (.[""] // {}) end;

    # A time to compare: a number as-is, or an ISO 8601 UTC time ("...Z", any fraction) in seconds.
    def stamp:
      if type == "number" then .
      elif type == "string" then
        ((capture("^(?<s>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(?<f>\\.[0-9]+)?Z$")
          | (.s + "Z" | fromdateiso8601) + ("0\(.f // "")" | tonumber)) // null)
      else null end;

    # The copy to keep of one credential. A refreshing credential records when in .[$k] (an
    # expiry or a refresh time): the later one wins, since it holds the current refresh
    # token. Any other difference (an API key, equal times) goes to the local copy only if
    # it changed since the last sync ($b); otherwise Doppler's copy wins. A credential
    # missing on one side is kept: a sync never deletes one.
    def newer($l; $r; $b):
      if $r == null then $l
      elif $l == null then $r
      else
        ($l[$k] | stamp) as $lt
        | ($r[$k] | stamp) as $rt
        | if $lt != null and $rt != null and $lt != $rt then (if $lt > $rt then $l else $r end)
          elif $l != $b then $l
          else $r end
      end;
    def merge($l; $r; $b):
      reduce (($l + $r) | keys[]) as $p ({}; .[$p] = newer($l[$p]; $r[$p]; $b[$p]));

    try (
      (env.LOCAL | parse("the local file") | split("the local file")) as $local
      # The secret is { <$e>: file, meta: { lastRefreshed } }. A secret without <$e> (the
      # file pasted into Doppler as it is) is the file itself, wrapped on the first write-back.
      | (env.REMOTE | parse("the Doppler secret")) as $doc
      | ($doc | has($e)) as $wrapped
      | (if $wrapped then $doc[$e] else $doc end
          | if type == "object" then . else fail("\($e) in the Doppler secret is not a JSON object") end
          | split("the Doppler secret")) as $remote
      | (if $wrapped and ($doc.meta | type) == "object" then $doc.meta.lastRefreshed else null end) as $refreshed
      | if $mode == "pull" then
          merge($local; $remote; $local) as $merged
          | { lastRefreshed: $refreshed, file: ($merged | join), changed: ($merged != $local) }
        else
          (env.BASE | parse("the synced file") | split("the synced file")) as $base
          | merge($local; $remote; $base) as $merged
          | {
              lastRefreshed: $refreshed,
              value: (
                if $merged != $remote or ($wrapped | not) and $merged != {} then
                  { ($e): ($merged | join), meta: { lastRefreshed: $now } }
                else null end
              )
            }
        end
    ) catch (
      # Only report messages written here: jq's own errors can quote parts of the input.
      if type == "string" and startswith("sync: ") then { error: .[6:] }
      else { error: "unexpected data" } end
    )
  '';
in
{
  options.doppler = {
    project = lib.mkOption {
      type = lib.types.str;
      default = "global";
      description = "Default Doppler project for bare `doppler` commands (DOPPLER_PROJECT).";
    };
    config = lib.mkOption {
      type = lib.types.str;
      default = "lf";
      description = "Default Doppler config for bare `doppler` commands (DOPPLER_CONFIG).";
    };
  };

  config = {
    # `withDopplerSecrets { name, project, config, program, secrets ? [ ] }`: a launcher
    # that runs `program` with the secrets of one Doppler config (all of them, or only
    # `secrets` when listed). Without Doppler auth it runs `program` without them, so a
    # tool's own stored login still works.
    _module.args.withDopplerSecrets = mkLauncher;

    # `withDopplerSyncedFile { name, project, config, program, path, secret, envelopeKey,
    # entries ? true, timeKey ? "expires", lock ? { mkdir = "<path>.lock"; },
    # removeOnExit ? false, secrets ? [ ] }`: `withDopplerSecrets`, plus a mutable JSON
    # credentials file `path` shared across machines through the Doppler secret `secret`,
    # stored as `{ <envelopeKey>: <file>, "meta": { "lastRefreshed": <ms> } }`.
    #
    # - `entries`: the file is an object of independent credentials, merged one by one (Pi's
    #   auth.json: one per provider). `false`: the whole file is one credential (Codex).
    # - `timeKey`: the key, in each credential, whose later value marks the newer copy: a
    #   number (Pi's `expires`) or an ISO 8601 UTC time (Codex's `last_refresh`).
    # - `lock`: the lock `program` takes on the file, so a sync never interleaves with its
    #   writes: `{ mkdir = <dir>; }` (proper-lockfile, Pi) or `{ flock = <file>; }` (Codex).
    #
    # - Before `program` starts, credentials that are newer in Doppler are merged into the
    #   file. A secret without `envelopeKey` (the file pasted into Doppler as it is) is taken
    #   as the file and wrapped on the first write-back, so nothing needs preparing.
    # - After it exits (also after SIGINT, SIGTERM or SIGHUP), the secret is fetched again and
    #   written back only if some local credential is newer: the later `timeKey` wins, and
    #   one without it (an API key) only if it changed during the run. meta.lastRefreshed is
    #   set then and reports writes by other runs (any machine) meanwhile.
    # - With `removeOnExit`, the file is then deleted, but only once Doppler holds everything in
    #   it and no other run of this launcher on the machine still uses it (a shared flock on the
    #   file's directory). When the write-back fails, the file stays until the next run.
    #
    # Doppler has no conditional write, so two machines exiting at once can overwrite each
    # other; the newer credential stays in the losing machine's file and is written back after
    # its next run. Removing a credential locally does not remove it from Doppler. The file is
    # written atomically (mode 600), and `secret` is kept out of the program's environment.
    _module.args.withDopplerSyncedFile =
      {
        name,
        project,
        config,
        program,
        path,
        secret,
        envelopeKey,
        entries ? true,
        timeKey ? "expires",
        lock ? {
          mkdir = "${path}.lock";
        },
        removeOnExit ? false,
        secrets ? [ ],
      }:
      assert lib.assertMsg (
        lib.attrNames lock == [ "mkdir" ] || lib.attrNames lock == [ "flock" ]
      ) "withDopplerSyncedFile: lock must be { mkdir = <dir>; } or { flock = <file>; }";
      let
        sync = pkgs.writeShellApplication {
          name = "${name}-doppler-sync";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.jq
            pkgs.util-linux
          ];
          text = ''
            doppler=${doppler}
            scope=(--project ${lib.escapeShellArg project} --config ${lib.escapeShellArg config})
            secret=${lib.escapeShellArg secret}
            file=$(realpath -m -- ${lib.escapeShellArg path})
            lock_kind="${lib.head (lib.attrNames lock)}"
            lock=$(realpath -m -- ${lib.escapeShellArg (lib.head (lib.attrValues lock))})
            remove_on_exit=${lib.optionalString removeOnExit "1"}
            pulled=''${!secret:-}
            unset "$secret"

            warn() { printf '%s: %s\n' ${lib.escapeShellArg name} "$*" >&2 || true; }

            # Every run holds a shared lock on the file's directory; only the last one to exit
            # can take it exclusively, so only that one removes the file.
            mkdir -p -- "$(dirname -- "$file")"
            exec {sessions}<"$(dirname -- "$file")"
            flock -s "$sessions"

            # The program's own lock on the file: a proper-lockfile directory (abandoned after
            # 10 s untouched) or an flock on a file.
            held=
            unlock() {
              if [[ -n $held ]]; then
                if [[ $lock_kind == flock ]]; then
                  exec {lockfd}>&-
                else
                  rmdir -- "$lock" 2>/dev/null || true
                fi
                held=
              fi
            }
            trap unlock EXIT
            lock() {
              local i mtime
              if [[ $lock_kind == flock ]]; then
                if exec {lockfd}>>"$lock"; then
                  if flock -x -w 10 "$lockfd"; then
                    held=1
                    return 0
                  fi
                  exec {lockfd}>&-
                fi
              else
                for ((i = 0; i < 100; i++)); do
                  if mkdir -- "$lock" 2>/dev/null; then
                    held=1
                    return 0
                  fi
                  if [[ -d $lock ]] && mtime=$(stat -c %Y -- "$lock" 2>/dev/null) &&
                    (($(date +%s) - mtime > 10)) && rmdir -- "$lock" 2>/dev/null; then
                    continue
                  fi
                  sleep 0.1
                done
              fi
              warn "$lock is held by another process; not syncing $secret"
              return 1
            }

            merge() { # MODE; LOCAL, REMOTE and BASE in the environment
              jq -nc --arg mode "$1" \
                --arg e ${lib.escapeShellArg envelopeKey} \
                --arg k ${lib.escapeShellArg timeKey} \
                --argjson entries ${lib.boolToString entries} \
                --argjson now "$(date +%s%3N)" \
                --from-file ${mergeCredentials} 2>/dev/null | grep .
            }
            field() { OUT=$1 jq -nr --arg f "$2" '(env.OUT | fromjson)[$f] // empty | if type == "string" then . else tojson end'; }

            # Merge newer Doppler credentials into the file; BASE is the file afterwards.
            base=
            refreshed=
            if lock; then
              base=$(cat -- "$file" 2>/dev/null || true)
              if ! out=$(LOCAL=$base REMOTE=$pulled merge pull); then
                warn "could not merge $secret into $file"
              elif err=$(field "$out" error) && [[ -n $err ]]; then
                warn "$err; left $file as it is"
              else
                refreshed=$(field "$out" lastRefreshed)
                base=$(field "$out" file)
                tmp=
                if [[ $(field "$out" changed) == true ]] &&
                  ! { tmp=$(mktemp -- "$file.XXXXXX") && jq . <<<"$base" >"$tmp" && mv -f -- "$tmp" "$file"; }; then
                  warn "could not write $file"
                  rm -f -- "$tmp"
                fi
              fi
              unlock
            fi

            # Outlive the signal that ends the program, so its credentials are still written back.
            trap : INT TERM HUP
            status=0
            ${program} "$@" {sessions}<&- || status=$?
            trap - INT TERM HUP

            # Write back credentials that are newer locally than in Doppler now.
            current=
            synced=
            if ! remote=$("$doppler" secrets get "$secret" "''${scope[@]}" --raw --plain --no-exit-on-missing-secret --silent); then
              warn "could not read $secret from Doppler; newer credentials stay in $file until the next run"
            elif lock; then
              current=$(cat -- "$file" 2>/dev/null || true)
              unlock
              if ! out=$(LOCAL=$current REMOTE=$remote BASE=$base merge push); then
                warn "could not merge $file into $secret"
              elif err=$(field "$out" error) && [[ -n $err ]]; then
                warn "$err; not writing back $secret"
              else
                latest=$(field "$out" lastRefreshed)
                if [[ -n $refreshed && -n $latest && $latest != "$refreshed" ]]; then
                  warn "$secret was updated by another run during this one; the newer copy of each credential won"
                fi
                if ! value=$(field "$out" value) || [[ -z $value ]]; then
                  synced=1
                elif printf '%s' "$value" | "$doppler" secrets set "$secret" "''${scope[@]}" --silent >/dev/null; then
                  synced=1
                  warn "wrote newer credentials back to $secret"
                else
                  warn "could not write $secret to Doppler; newer credentials stay in $file until the next run"
                fi
              fi
            fi

            # Remove the file once Doppler holds all of it, unless another run still uses it.
            if [[ -n $remove_on_exit && -n $synced ]] && flock -x -n "$sessions" && lock; then
              if [[ $(cat -- "$file" 2>/dev/null || true) == "$current" ]]; then
                rm -f -- "$file"
              else
                warn "$file changed during the write-back; keeping it until the next run"
              fi
              unlock
            fi
            exit "$status"
          '';
        };
      in
      mkLauncher {
        inherit
          name
          project
          config
          program
          ;
        run = lib.getExe sync;
        secrets = lib.optionals (secrets != [ ]) (secrets ++ [ secret ]);
      };

    home.sessionVariables = {
      DOPPLER_PROJECT = cfg.project;
      DOPPLER_CONFIG = cfg.config;
    };
  };
}
