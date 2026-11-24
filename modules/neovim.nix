{ inputs, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withNodeJs = true;
    withPython3 = true;

    # Scope editor tooling to Neovim rather than the user global PATH.
    extraPackages = with pkgs; [
      fd
      ripgrep
      git

      bash-language-server
      gopls
      lua-language-server
      nil
      pyright
      taplo
      typescript
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

  xdg.configFile."nvim/colors/vercel.lua".source = ./neovim/colors/vercel.lua;
  xdg.configFile."nvim/lua/nixpkgs_completion.lua".text = ''
    local packages = 'path:${inputs.nixpkgs}#legacyPackages.${pkgs.stdenv.hostPlatform.system}'
  ''
  + builtins.readFile ./neovim/nixpkgs_completion.lua;
}
