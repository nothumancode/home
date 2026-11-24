{
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
        nixfmt
        statix
      ];
      formatter = "nixfmt";
      linter = "statix";
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
      linter = "shellcheck";
    }
    {
      filetypes = [ "python" ];
      packages = [ ruff ];
      formatter = "ruff_format";
      linter = "ruff";
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
      linter = "yamllint";
    }
  ];

  packages = lib.unique (lib.concatMap (lang: lang.packages) languages);
  byFiletype =
    adapter:
    lib.listToAttrs (
      lib.concatMap (lang: map (ft: lib.nameValuePair ft [ lang.${adapter} ]) lang.filetypes) (
        lib.filter (lang: builtins.hasAttr adapter lang) languages
      )
    );
in
{
  # nixfmt-tree provides the treefmt command; never run it as a buffer formatter.
  home.packages = packages ++ [ pkgs.nixfmt-tree ];

  programs.neovim.extraPackages = lib.mkIf config.programs.neovim.enable packages;
  xdg.configFile."nvim/lua/dev_tools.lua" = lib.mkIf config.programs.neovim.enable {
    text =
      "return "
      + lib.generators.toLua { } {
        formatters = byFiletype "formatter";
        linters = byFiletype "linter";
      };
  };
}
