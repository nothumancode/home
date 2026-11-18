# Home Manager

[`modules/dotenvx.nix`](modules/dotenvx.nix) loads dotenvx values into the
shell, not into individual application launchers. Run `claude`, `pi`, and
`cachix` normally; they inherit the environment of the shell that starts them.

## Every interactive Bash session

Add only variables you want **every child process** to inherit to `shellTokens`:

```nix
shellTokens = {
  CACHIX_AUTH_TOKEN = ../secrets/.env.cachix;
  EXA_API_KEY = ../secrets/.env.exa;
};
```

At startup Bash runs `dotenvx get` for each named variable that isn't already
nonempty, then exports the value if decryption succeeds and it isn't empty.
It doesn't source the file or evaluate the decrypted text as shell code.
Several names can use the same encrypted file.

WSL restarts clear environment variables. Supply the matching private keys
(e.g. `DOTENV_PRIVATE_KEY_CACHIX`) at shell startup, or keep a private dotenvx
`.env.keys` file at `${XDG_CONFIG_HOME:-$HOME/.config}/dotenvx/.env.keys`
(mode `0600`, outside the repo). The Bash hook uses that file if readable.
Commit only ciphertext and public keys; never put plaintext or private keys in
Git, Nix expressions, or `home.sessionVariables`. Rebuild Home Manager and open
a new shell after changing the global map.

For a one-off project shell, run `dotenvx run --strict -o -f .env -- bash -i`.
Type `exit` to return to the unchanged parent shell.
