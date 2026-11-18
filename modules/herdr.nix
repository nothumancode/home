{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = import ../themes/palette.nix;
in
{
  programs.herdr = {
    enable = true;
    # Preserve local choices and let the in-app settings UI keep working.
    mutableSettings = true;
    settings = {
      onboarding = false;
      update.version_check = false; # The flake, not the self-updater, owns the binary.
      theme = {
        name = "vesper";
        auto_switch = false;
        custom = {
          accent = c.white;
          panel_bg = c.panel;
          sidebar_bg = c.canvas;
          active_row_bg = c.surface;
          selection_bg = c.selection;
          surface_dim = c.panel;
          surface0 = c.border;
          surface1 = c.strongBorder;
          overlay0 = c.quiet;
          overlay1 = c.muted;
          subtext0 = c.muted;
          text = c.text;
          mauve = c.text;
          peach = c.amber;
          yellow = c.amber;
          inherit (c)
            red
            green
            blue
            teal
            ;
        };
      };

      terminal.new_cwd = "follow";
      ui = {
        agent_panel_sort = "priority";
        status_indicators = "symbols";
        show_agent_labels_on_pane_borders = true;
        toast.delivery = "herdr";
        sound.enabled = false;
        pane_gaps = false;
        pane_outer_borders = false;
        prompt_new_tab_name = false;
        window_title = "{workspace}: {tab}";
      };

      # Prefix-only shortcuts leave ordinary typing in Neovim, Pi and shells alone.
      keys = {
        open_worktree = "prefix+t";
        command = [
          {
            key = "prefix+f";
            type = "pane";
            command = "${lib.getExe config.programs.neovim.finalPackage} .";
            description = "Edit this directory in Neovim";
          }
          {
            key = "prefix+i";
            type = "pane";
            command = "${lib.getExe config.programs.pi-coding-agent.package}";
            description = "Start Pi here";
          }
          {
            key = "prefix+u";
            type = "popup";
            command = lib.getExe pkgs.lazygit;
            description = "Git status, diffs and staging";
            width = "90%";
            height = "85%";
          }
        ];
      };
    };
  };
}
