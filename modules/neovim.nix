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

    # Scope editor tooling to Neovim rather than the user's global PATH.
    extraPackages = with pkgs; [
      fd
      ripgrep
      git

      bash-language-server
      gopls
      lua-language-server
      nil
      pyright
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
          go
          gomod
          gosum
          html
          javascript
          json
          lua
          markdown
          markdown_inline
          nix
          python
          tsx
          typescript
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
