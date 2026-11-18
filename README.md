# Home Manager

## Command-scoped secrets

[`modules/dotenvx.nix`](modules/dotenvx.nix) installs `with-secrets COMMAND [ARG...]`.
Use it from any directory to give a command the values from `secrets/.env.global`
without exporting them in your login shell. Run `claude` and `pi` directly:
they already load that file plus `secrets/claude.env` or `secrets/pi.env`,
respectively. App values override shared values, which override inherited values.
A decryption error stops the command. The launcher removes `DOTENV_PRIVATE_KEY*`
from the app's environment after decryption.

### Provision a shared secret

1. In a private directory **outside this checkout**, prepare a file named
   `.env.global` containing only values all these commands should receive.
   Run `dotenvx encrypt -f .env.global`. Back up the matching private key
   in your password manager. Copy **only the encrypted file** over
   `secrets/.env.global` (initially empty), then rebuild Home Manager.
2. On each machine, supply `DOTENV_PRIVATE_KEY_GLOBAL` to the launcher at
   runtime. For example, with a 1Password item of your own:

   ```sh
   DOTENV_PRIVATE_KEY_GLOBAL="$(op read 'op://Personal/home-manager/dotenv-key')" \
     with-secrets your-command arg
   ```

The existing app files still use their original keys
(`DOTENV_PRIVATE_KEY_CLAUDEDEVELOPMENT` and `DOTENV_PRIVATE_KEY_PIDEVELOPMENT`).
If they use the same credential, move it to the shared file and remove the
app-specific copies once verified (an empty app file is fine). For distinct
values but one decryption key, encrypt **fresh** app files with
`dotenvx encrypt --with "$global_public_key" -f <file>` using the shared file's
public key. Renaming an existing ciphertext does not re-key it.

## Tokens in interactive Bash

Add one entry to `shellTokens` in `modules/dotenvx.nix` for each variable
you want in every interactive Bash session:

```nix
shellTokens = {
  CACHIX_AUTH_TOKEN = ../secrets/.env.cachix;
  # OTHER_API_TOKEN = ../secrets/.env.work;
};
```

The name on the left must match the key in the encrypted file. Several names
can point to the same file. For a new file, allowlist its exact path in
`.gitignore` and add **only its ciphertext** to Git before rebuilding. Bash
leaves a nonempty value alone and exports a missing value only if decryption
succeeds and the result is nonempty. These exports are inherited by child
processes, including Claude and Pi; use a command wrapper for app-only secrets.

WSL restarts clear environment variables. Supply the matching dotenvx private
key at shell startup (e.g. `DOTENV_PRIVATE_KEY_CACHIX` from a password manager),
or keep a private dotenvx `.env.keys` file at
`${XDG_CONFIG_HOME:-$HOME/.config}/dotenvx/.env.keys` (mode `0600`, outside
the repo). The Bash hook uses that file if readable. After a Home Manager
switch, open a new Bash session; check with `[[ -n ${CACHIX_AUTH_TOKEN:-} ]]`
rather than printing the token.

Keep private keys and plaintext out of Git, Nix expressions, and
`home.sessionVariables`; the Nix store is readable by other local users.
