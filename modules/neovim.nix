{ lib, pkgs, ... }:

let
  palette = import ../themes/palette.nix;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      nvim-lspconfig
      mini-nvim
      conform-nvim
      # Neovim already ships parsers for Lua, Markdown, Vim and help.
      (nvim-treesitter.withPlugins (g: [
        g.bash
        g.css
        g.go
        g.gomod
        g.gosum
        g.gowork
        g.html
        g.javascript
        g.json
        g.nix
        g.python
        g.toml
        g.tsx
        g.typescript
        g.yaml
      ]))
    ];

    # The wrapper supplies tools without exposing a second global toolchain.
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      bash-language-server
      shellcheck
      ty
      ruff
      typescript # TypeScript 7 includes the native tsc --lsp server.
      vscode-langservers-extracted
      yaml-language-server
      gopls
      go # gopls needs the go command; also provides gofmt.

      nixfmt
      prettier
      shfmt
      stylua
      ripgrep
      fd
      git
    ];

    initLua = builtins.readFile ../config/nvim/init.lua;
  };

  xdg.configFile."nvim/lua/vercel_palette.lua".text = "return ${lib.generators.toLua { } palette}\n";
  xdg.configFile."nvim/colors/vercel-dark.lua".source = ../themes/vercel-dark.lua;
}
