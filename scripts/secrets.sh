# shellcheck shell=bash
# Manage the secrets of this Home Manager configuration.
#
#   secrets/env.yaml       sops file; each entry becomes a shell environment variable
#   secrets/identity.age   the age key that decrypts it, wrapped with a passphrase
#   .sops.yaml             the matching public key
#
# The unwrapped key lives outside the repository, in the sops key file.

usage() {
  cat <<'EOF'
Usage: secrets <command>

  status       Show the key state and the names of the stored variables
  set NAME     Store a variable; the value is read from the terminal or stdin
  unset NAME   Remove a variable
  unlock       Install the key on this machine (asks for the passphrase)
  init         Create the key for this repository (first use only)
  rotate       Replace the key and passphrase, then re-encrypt

After `set`, `unset` or `rotate`: commit, run `hms`, open a new shell.
EOF
}

die() {
  printf 'secrets: %s\n' "$*" >&2
  exit 1
}

say() {
  printf '%s\n' "$*" >&2
}

repo=${SECRETS_REPO:-${XDG_CONFIG_HOME:-$HOME/.config}/home-manager}
[[ -f $repo/flake.nix ]] || die "no Home Manager repository at $repo"
# sops matches file paths against .sops.yaml relative to the repository root.
cd "$repo" || die "cannot enter $repo"

env_file=$repo/secrets/env.yaml
identity=$repo/secrets/identity.age
sops_config=$repo/.sops.yaml
key_file=${SOPS_AGE_KEY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt}
export SOPS_AGE_KEY_FILE=$key_file

# Unfinished output and the temporary copy of the key never outlive the script.
scratch=
trap 'rm -f "$identity.new" "$env_file.new" ${scratch:+"$scratch"}' EXIT

# The age public key that files under secrets/ are encrypted to.
recipient() {
  [[ -f $sops_config ]] && grep -oE 'age1[0-9a-z]{58}' "$sops_config" | head -n 1
}

# True when the key file holds the identity for that public key.
unlocked() {
  local public
  public=$(recipient) && [[ -n $public && -r $key_file ]] &&
    age-keygen -y "$key_file" 2>/dev/null | grep -qxF "$public"
}

require_key() {
  [[ -f $sops_config ]] || die "this repository has no key yet; run 'secrets init'"
  unlocked || die "this machine does not have the key; run 'secrets unlock'"
}

valid_name() {
  [[ ${1:-} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

# A private file next to the key file, removed when the script exits.
make_scratch() {
  install -d -m 700 "$(dirname "$key_file")"
  scratch=$(mktemp "$(dirname "$key_file")/tmp.XXXXXX")
}

# Add the identity in $scratch to the key file. Other identities stay.
install_identity() {
  (umask 077 && cat "$scratch" >>"$key_file")
  chmod 600 "$key_file"
}

write_sops_config() {
  cat >"$sops_config" <<EOF
# Files under secrets/ are encrypted to this age public key.
# Written by \`secrets init\` and \`secrets rotate\`.
creation_rules:
  - path_regex: ^secrets/[^/]+\\.yaml\$
    age: $1
EOF
}

# Write $scratch, protected by a passphrase, to secrets/identity.age.
wrap_identity() {
  say "Choose a passphrase for the copy of the key that is stored in the repository."
  say "Leave it empty and age generates a strong one."
  say "Keep it in your password manager: a new machine needs only this passphrase."
  mkdir -p "$repo/secrets"
  age --encrypt --passphrase --armor --output "$identity.new" "$scratch"
  mv "$identity.new" "$identity"
}

# Flakes read only the files that Git tracks.
stage() {
  git -C "$repo" add -- .sops.yaml secrets 2>/dev/null || true
}

# Store NAME ($1) with the value ($2). The value never appears in a command line.
put() {
  if [[ -f $env_file ]]; then
    printf '%s' "$2" | jq -Rs . | sops set --value-stdin secrets/env.yaml "[\"$1\"]"
  else
    printf '%s' "$2" | jq -Rs --arg name "$1" '{($name): .}' |
      sops encrypt --filename-override secrets/env.yaml \
        --input-type json --output-type yaml /dev/stdin >"$env_file.new"
    mv "$env_file.new" "$env_file"
  fi
}

cmd_status() {
  say "Repository: $repo"
  if [[ ! -f $sops_config ]]; then
    say "Key:        none yet; run 'secrets init'"
  elif unlocked; then
    say "Key:        installed in $key_file"
  else
    say "Key:        not on this machine; run 'secrets unlock'"
  fi
  say "Variables:"
  if [[ -f $env_file ]]; then
    grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$env_file" | grep -vx sops | sed 's/^/  /' || true
    if unlocked && ! sops decrypt --output-type dotenv secrets/env.yaml >/dev/null 2>&1; then
      say "Warning: secrets/env.yaml cannot be loaded. Keep it a flat list of 'NAME: value'."
    fi
  fi
}

cmd_set() {
  valid_name "${1:-}" || die "usage: secrets set NAME (NAME is a shell variable name)"
  require_key
  local value
  if [[ -t 0 ]]; then
    read -rsp "Value for $1: " value
    echo >&2
  else
    value=$(cat)
  fi
  [[ -n $value ]] || die "the value is empty"
  put "$1" "$value"
  stage
  say "Stored $1."
}

cmd_unset() {
  valid_name "${1:-}" || die "usage: secrets unset NAME"
  require_key
  [[ -f $env_file ]] || die "there are no stored variables"
  sops unset secrets/env.yaml "[\"$1\"]"
  stage
  say "Removed $1."
}

cmd_unlock() {
  [[ -f $identity ]] || die "no secrets/identity.age in $repo; run 'secrets init' first"
  if unlocked; then
    say "The key is already installed on this machine."
    return
  fi
  make_scratch
  say "Enter the passphrase for secrets/identity.age."
  age --decrypt --output "$scratch" "$identity"
  install_identity
  unlocked || die "the key in secrets/identity.age does not match .sops.yaml"
  say "Key installed in $key_file. Open a new shell to load the variables."
}

cmd_init() {
  [[ ! -e $identity && ! -e $sops_config ]] ||
    die "this repository already has a key; use 'secrets rotate' to replace it"
  make_scratch
  age-keygen 2>/dev/null >"$scratch"
  wrap_identity
  write_sops_config "$(age-keygen -y "$scratch")"
  install_identity
  stage
  say "Key created. Add variables with 'secrets set NAME', then commit."
}

cmd_rotate() {
  require_key
  make_scratch
  age-keygen 2>/dev/null >"$scratch"
  wrap_identity
  # The key file now holds the old and the new identity, as re-encryption needs.
  install_identity
  write_sops_config "$(age-keygen -y "$scratch")"
  if [[ -f $env_file ]]; then
    sops updatekeys --yes secrets/env.yaml
    sops rotate --in-place secrets/env.yaml
  fi
  stage
  say "Key replaced. Commit and push, then run 'secrets unlock' on each other machine."
  say "Old commits stay readable with the old key. If that key leaked, also replace"
  say "each token at its provider."
}

# One-time migration from the dotenvx files this repository used before.
# Delete this function and its case branch when secrets/.env.* no longer exist.
cmd_import_dotenvx() {
  require_key
  command -v dotenvx >/dev/null ||
    die "dotenvx is not on PATH; run: nix shell --inputs-from $repo nixpkgs#dotenvx -c secrets import-dotenvx"
  local keys=${XDG_CONFIG_HOME:-$HOME/.config}/dotenvx/.env.keys
  local -a key_args=()
  [[ ! -r $keys ]] || key_args=(-fk "$keys")

  local file name value complete
  for file in "$repo"/secrets/.env.*; do
    [[ -f $file ]] || continue
    complete=1
    while IFS= read -r name; do
      if value=$(cd / && dotenvx get "$name" --quiet --strict -o -f "$file" "${key_args[@]}" 2>/dev/null) &&
        [[ -n $value && $value != encrypted:* ]]; then
        put "$name" "$value"
        say "Imported $name."
      else
        say "Could not decrypt $name from ${file##*/}. Store it with: secrets set $name"
        complete=0
      fi
    done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$file" | grep -v '^DOTENV_PUBLIC_KEY' || true)
    if [[ $complete -eq 1 ]]; then
      rm -f "$file"
    else
      say "Kept ${file##*/}. Delete it when its values are stored."
    fi
  done
  stage
}

case ${1:-} in
  status) cmd_status ;;
  set) cmd_set "${2:-}" ;;
  unset) cmd_unset "${2:-}" ;;
  unlock) cmd_unlock ;;
  init) cmd_init ;;
  rotate) cmd_rotate ;;
  import-dotenvx) cmd_import_dotenvx ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
