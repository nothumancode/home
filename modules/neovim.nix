{ inputs, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    # The configuration is pure Lua with no remote plugins, so no provider hosts.
    withNodeJs = false;
    withPython3 = false;

    # Language servers live only on Neovim's PATH; formatters, linters and the Python
    # servers (ty, ruff) come from modules/dev-tools.nix, and fd/ripgrep/git are global.
    extraPackages = with pkgs; [
      bash-language-server
      gopls
      lua-language-server
      marksman
      nil
      typescript # tsserver for typescript-language-server
      typescript-language-server
      vscode-langservers-extracted
      yaml-language-server
    ];

    plugins = with pkgs.vimPlugins; [
      blink-cmp
      friendly-snippets
      conform-nvim
      mini-nvim
      nvim-lint
      nvim-lspconfig
      nvim-treesitter-context
      nvim-treesitter-textobjects # queries for mini.ai's function/class/block text objects
      SchemaStore-nvim
      which-key-nvim
      (nvim-treesitter.withPlugins (
        p: with p; [
          bash
          css
          diff
          dockerfile
          git_config
          git_rebase
          gitcommit
          gitignore
          go
          gomod
          gosum
          html
          javascript
          jsdoc
          json
          lua
          luadoc
          make
          markdown
          markdown_inline
          nix
          python
          query
          regex
          rust
          sql
          toml
          tsx
          typescript
          vim
          vimdoc
          xml
          yaml
        ]
      ))
    ];

    initLua = builtins.readFile ./neovim/init.lua;
  };

  xdg.configFile = {
    "nvim/colors/vercel.lua".source = ./neovim/colors/vercel.lua;
    # theme, editor, languages, terminals and :checkhealth home, required by init.lua.
    "nvim/lua/home".source = ./neovim/lua/home;
    "nvim/lua/nixpkgs_completion.lua".text = ''
      local packages = 'path:${inputs.nixpkgs}#legacyPackages.${pkgs.stdenv.hostPlatform.system}'
    ''
    + builtins.readFile ./neovim/nixpkgs_completion.lua;
  };
}
