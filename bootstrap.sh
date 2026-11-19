#!/bin/sh
# Set up this Home Manager configuration on a new machine: Nix, the secrets
# key, then the first activation. It is safe to run this script again.
set -eu

repo=$(cd "$(dirname "$0")" && pwd -P)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
user=${USER:-$(id -un)}

say() {
  printf '%s\n' "$*"
}

die() {
  printf 'bootstrap: %s\n' "$*" >&2
  exit 1
}

# Put Nix on PATH when it is installed but this shell started before that.
load_nix() {
  for profile in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
    if [ -r "$profile" ]; then
      set +u
      # shellcheck disable=SC1090
      . "$profile"
      set -u
    fi
  done
}

command -v nix >/dev/null 2>&1 || load_nix

if ! command -v nix >/dev/null 2>&1; then
  if [ "$(uname -s)" = Linux ] && [ ! -d /run/systemd/system ]; then
    die "Nix is not installed, and this system does not run systemd, which the
Nix daemon needs. On WSL, add the two lines below to /etc/wsl.conf, run
'wsl.exe --shutdown' from Windows, then run this script again.

    [boot]
    systemd=true"
  fi
  say "Nix is not installed. Starting the installer from https://github.com/NixOS/nix-installer."
  curl --proto '=https' --tlsv1.2 -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install
  load_nix
  command -v nix >/dev/null 2>&1 ||
    die "Nix is installed but not on PATH. Open a new terminal and run this script again."
fi

# Not every Nix installer enables flakes.
features=$(nix --extra-experimental-features nix-command config show experimental-features 2>/dev/null || true)
case " $features " in
  *" flakes "*) ;;
  *)
    mkdir -p "$config_home/nix"
    printf 'extra-experimental-features = nix-command flakes\n' >>"$config_home/nix/nix.conf"
    say "Enabled flakes in $config_home/nix/nix.conf."
    ;;
esac

# The 'hms' alias and the 'secrets' command look for the repository here.
link=$config_home/home-manager
if [ ! -e "$link" ]; then
  mkdir -p "$config_home"
  ln -s "$repo" "$link"
  say "Linked $link to $repo."
elif [ "$(cd "$link" && pwd -P)" != "$repo" ]; then
  say "Warning: $link is not this repository. 'hms' and 'secrets' use $link."
fi

if [ "$(nix eval "$repo#homeConfigurations" --apply "configs: configs ? \"$user\"")" != true ]; then
  die "there is no configuration for the account '$user'. Add it to 'users' in
$repo/flake.nix, then run this script again."
fi

if [ -f "$repo/secrets/identity.age" ]; then
  SECRETS_REPO=$repo nix run "$repo#secrets" -- unlock ||
    say "Warning: the secrets key is not installed. Run 'secrets unlock' later."
fi

nix run "$repo#home-manager" -- switch -b backup --flake "$repo"

# 'gh auth login' run from 'nix shell' stores a Git credential helper in
# ~/.gitconfig that names a store path, and garbage collection removes that
# path later. The activated configuration provides the helper, so drop the entry.
git=$(command -v git || printf '%s' "$HOME/.nix-profile/bin/git")
if [ -f "$HOME/.gitconfig" ] && [ -x "$git" ]; then
  for host in https://github.com https://gist.github.com; do
    if "$git" config --file "$HOME/.gitconfig" --get-all "credential.$host.helper" 2>/dev/null |
      grep -q /nix/store/; then
      "$git" config --file "$HOME/.gitconfig" --unset-all "credential.$host.helper"
      say "Removed the temporary Git credential helper for $host from ~/.gitconfig."
    fi
  done
fi

say "Done. Open a new terminal to use the new environment."
