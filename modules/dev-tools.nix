{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  # Each entry installs CLI packages and maps filetypes to Conform and
  # nvim-lint adapter names (which can differ from the executable names).
  languages = with pkgs; [
    {
      filetypes = [ "nix" ];
      packages = [
        deadnix
        nixfmt
        statix
      ];
      formatter = "nixfmt";
      linters = [
        "statix"
        "deadnix"
      ];
    }
    {
      filetypes = [
        "sh"
        "bash"
      ];
      packages = [
        shfmt
        shellcheck
      ];
      formatter = "shfmt";
      linters = [ "shellcheck" ];
    }
    {
      # Neovim runs both as language servers: ty for types and navigation, Ruff for lint and fixes.
      filetypes = [ "python" ];
      packages = [
        ruff
        ty
      ];
      formatter = "ruff_format";
    }
    {
      filetypes = [ "lua" ];
      packages = [ stylua ];
      formatter = "stylua";
    }
    {
      filetypes = [
        "javascript"
        "javascriptreact"
        "typescript"
        "typescriptreact"
        "css"
        "html"
        "json"
        "markdown"
      ];
      packages = [ prettier ];
      formatter = "prettier";
    }
    {
      filetypes = [ "yaml" ];
      packages = [
        prettier
        yamllint
      ];
      formatter = "prettier";
      linters = [ "yamllint" ];
    }
    {
      filetypes = [ "toml" ];
      packages = [ taplo ];
      formatter = "taplo";
    }
    {
      filetypes = [ "dockerfile" ];
      packages = [ hadolint ];
      linters = [ "hadolint" ];
    }
  ];

  extraCliPackages = with pkgs; [
    # Wit CLI for agents and humans
    inputs.wit.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Kanban `todomd` CLI
    inputs.kbtd.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Provides the treefmt-wrapped project formatter; never run as a single-buffer formatter.
    nixfmt-tree
  ];

  # Formatters and linters, on Neovim's PATH and globally for CLI/agent checks.
  # actionlint is scoped to .github/workflows/*.y*ml in Neovim, so it has no filetype entry.
  editorPackages = lib.unique (lib.concatMap (lang: lang.packages) languages ++ [ pkgs.actionlint ]);

  formattersByFiletype = lib.listToAttrs (
    lib.concatMap (lang: map (ft: lib.nameValuePair ft [ lang.formatter ]) lang.filetypes) (
      lib.filter (lang: lang ? formatter) languages
    )
  );

  lintersByFiletype = lib.listToAttrs (
    lib.concatMap (lang: map (ft: lib.nameValuePair ft lang.linters) lang.filetypes) (
      lib.filter (lang: lang ? linters) languages
    )
  );
in
{
  home.packages = editorPackages ++ extraCliPackages;

  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        charset = "utf-8";
        end_of_line = "lf";
        insert_final_newline = true;
        trim_trailing_whitespace = true;
        indent_style = "space";
        indent_size = 2;
      };
      "*.{py,pyi,rs}" = {
        indent_size = 4;
      };
      "{Makefile,*.mk,*.go,go.mod,go.sum}" = {
        indent_style = "tab";
        indent_size = 4;
      };
      "*.md" = {
        trim_trailing_whitespace = false;
      };
    };
  };

  programs.neovim.extraPackages = lib.mkIf config.programs.neovim.enable editorPackages;
  xdg.configFile."nvim/lua/dev_tools.lua" = lib.mkIf config.programs.neovim.enable {
    text =
      "return "
      + lib.generators.toLua { } {
        formatters = formattersByFiletype;
        linters = lintersByFiletype;
      };
  };
}
