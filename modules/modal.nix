{
  config,
  lib,
  pkgs,
  remoteFlake,
  ...
}:

let
  fnoxBin = lib.getExe' config.programs.fnox.package "fnox";
  ghBin = lib.getExe config.programs.gh.package;

  # `modal-sandbox [REV]`: a Modal sandbox with this configuration already activated.
  modalSandbox =
    pkgs.writers.writePython3Bin "modal-sandbox"
      {
        libraries = [ pkgs.python3Packages.modal ];
        flakeIgnore = [ "E501" ];
      }
      ''
        import argparse
        import contextlib
        import os
        import shlex
        import subprocess
        import sys

        import modal

        APP = "human-nix"
        REPO = ${builtins.toJSON (lib.removePrefix "github:" remoteFlake)}
        USER = ${builtins.toJSON config.home.username}
        HOME = ${builtins.toJSON config.home.homeDirectory}
        NIX_BIN = "/nix/var/nix/profiles/default/bin"
        # The activated profile first, so commands run in the sandbox find its tools.
        PATH = f"${config.home.profileDirectory}/bin:{NIX_BIN}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"


        def output(*command):
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode != 0:
                sys.exit(f"modal-sandbox: {command[0]} failed: {result.stderr.strip()}")
            return result.stdout.strip()


        def modal_credentials():
            """Modal's own environment or ~/.modal.toml wins; otherwise ask fnox."""
            if "MODAL_TOKEN_ID" in os.environ or os.path.exists(os.path.expanduser("~/.modal.toml")):
                return
            for key in ("MODAL_TOKEN_ID", "MODAL_TOKEN_SECRET"):
                os.environ[key] = output(${builtins.toJSON fnoxBin}, "--if-missing", "error", "get", key)


        def github_token():
            return modal.Secret.from_name("github", required_keys=["GITHUB_TOKEN"])


        def clone_command(url, branch):
            """Clone url into root's home; without a branch git takes the default one."""
            path = "/root/" + url.rstrip("/").removesuffix(".git").rsplit("/", 1)[-1]
            return shlex.join(["git", "clone", *(["--branch", branch] if branch else []), "--", url, path])


        def image(rev, repo, branch):
            # Modal's builder fails the installer's first Nix build unless the installer
            # writes to a file, so its log is only shown when it fails.
            install_nix = (
                "curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix"
                " | sh -s -- install linux --extra-conf 'sandbox = false' --init none --no-confirm"
                " >/tmp/nix-install.log 2>&1 || { cat /tmp/nix-install.log; exit 1; }"
            )
            # Modal always runs as root, so root's home is aliased as the configured one for
            # the activation (README, "Sandboxes"). The token is only needed while the
            # repository is private; it exists during this build step and is not stored.
            activate = (
                f"export PATH={NIX_BIN}:$PATH"
                f" && mkdir -p {os.path.dirname(HOME)} && ln -s /root {HOME}"
                f" && USER={USER} HOME={HOME}"
                ' NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"'
                f" nix run github:{REPO}/{rev}"
            )
            built = (
                modal.Image.debian_slim()
                .apt_install("ca-certificates", "curl", "git", "gnupg")
                .run_commands(install_nix)
                # Modal caches a layer until its definition changes, so the pinned commit
                # is what makes a new configuration rebuild this one.
                .run_commands(activate, secrets=[github_token()])
                .env({"PATH": PATH})
            )
            if repo:
                # A last layer rather than a command in the running sandbox: it needs only
                # Modal's API, and the token (for private repositories, through the
                # configured gh credential helper) never reaches the sandbox. Rebuilt on
                # every run so the clone is current.
                built = built.run_commands(clone_command(repo, branch), secrets=[github_token()], force_build=True)
            return built


        def main():
            parser = argparse.ArgumentParser(description="Create a Modal sandbox with this Home Manager configuration activated.")
            parser.add_argument("rev", nargs="?", default="main", help="commit, branch or tag of the configuration (default: main)")
            parser.add_argument("--app", default=APP, help=f"Modal app that owns the sandbox, created if missing (default: {APP})")
            parser.add_argument("--timeout", type=int, default=3600, help="seconds until Modal stops the sandbox (default: 3600)")
            parser.add_argument("--with-git-repo", metavar="URL", help="clone this repository into the sandbox's /root")
            parser.add_argument("--with-git-branch", metavar="BRANCH", help="branch to clone (default: the repository's default branch)")
            args = parser.parse_args()
            if args.with_git_branch and not args.with_git_repo:
                parser.error("--with-git-branch needs --with-git-repo")

            rev = output(${builtins.toJSON ghBin}, "api", f"repos/{REPO}/commits/{args.rev}", "--jq", ".sha")
            modal_credentials()
            app = modal.App.lookup(args.app, create_if_missing=True)

            # Build logs go to stderr, so stdout carries only the sandbox ID.
            with contextlib.redirect_stdout(sys.stderr), modal.enable_output():
                print(f"modal-sandbox: {REPO} at {rev}")
                built = image(rev, args.with_git_repo, args.with_git_branch).build(app)

            sandbox = modal.Sandbox.create(app=app, image=built, timeout=args.timeout)
            print(f"modal-sandbox: image {built.object_id}", file=sys.stderr)
            print(sandbox.object_id)


        try:
            main()
        except modal.exception.Error as error:
            sys.exit(f"modal-sandbox: {error}")
      '';
in
{
  home.packages = [
    modalSandbox
    pkgs.modal
  ];
}
