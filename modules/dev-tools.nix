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
      filetypes = [ "python" ];
      packages = [
        ruff
        ty
      ];
      formatter = "ruff_format";
      linters = [ "ruff" ];
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
    # Kanban `todomd` CLI
    inputs.kbtd.packages.${pkgs.stdenv.hostPlatform.system}.default
    # Scoped to .github/workflows/*.y*ml in Neovim; available globally for CLI/agent checks.
    actionlint
    # Provides the treefmt-wrapped project formatter; never run as a single-buffer formatter.
    nixfmt-tree
  ];

  packages = lib.unique (lib.concatMap (lang: lang.packages) languages);
  editorPackages = lib.unique (packages ++ [ pkgs.actionlint ]);

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
  home.packages = lib.unique (packages ++ extraCliPackages);

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
