{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "xterm-256color";
    baseIndex = 1;
    clock24 = true;
    mouse = true;
    historyLimit = 10000;
    extraConfig = ''
      # Config reload
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."

      # Renumber windows after closing
      set -g renumber-windows on

      # Colors
      bg="#0c0e0f"
      fg="#edeff0"
      red="#df5b61"
      green="#78b892"
      yellow="#de8f78"
      blue="#6791c9"
      purple="#bc83e3"
      orange="#E89982"
      gray="#343637"

      # Styles
      normal="fg=$fg,bg=$bg,nobold,nounderscore,noitalics"

      # Status widgets
      wg_session="#[fg=$bg,bg=$blue,bold] #S #[fg=$blue,bg=$bg]"
      wg_date_time="#[fg=$bg,bg=$blue,bold] %F %H%M"

      # Status
      set -g status on
      set -g status-position top

      set -g message-command-style "$normal"
      set -g pane-active-border-style "fg=#a89984"
      set -g status-style "$normal"
      set -g message-style "$normal"
      set -g pane-border-style "fg=#5a524c"
      setw -g window-status-activity-style "none,fg=#a89984,bg=#32302f"
      setw -g window-status-separator ""
      setw -g window-status-style "none,fg=#ddc7a1,bg=#32302f"

      set -g status-left "$wg_session"
      set -g status-right "#[fg=$blue]$wg_date_time #{prefix_highlight}"
      setw -g window-status-format "#[bg=$bg,fg=$fg] #I "
      setw -g window-status-current-format "#[fg=$yellow,bg=$bg]#[bg=$yellow,fg=$bg]#I#[fg=$yellow,bg=$bg]"

      set-option -g status-justify centre
      set-option -g status-left-length 100
      set-option -g status-right-length 100
    '';
    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.copycat
      tmuxPlugins.open
      tmuxPlugins.prefix-highlight
      {
        plugin = tmuxPlugins.yank;
        extraConfig = ''
          set -g @yank_selection 'clipboard' # or 'secondary' or 'primary'
          set -g @yank_selection_mouse 'clipboard' # or 'primary' or 'secondary'
        '';
      }
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
        '';
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-boot 'on'
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
  };
}
