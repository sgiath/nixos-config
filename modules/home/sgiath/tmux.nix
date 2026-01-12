{
  config,
  lib,
  pkgs,
  ...
}:

let
  bd-picker = pkgs.writeShellScriptBin "bd-picker" ''
    set -euo pipefail

    # ANSI color codes
    RESET='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    BLUE='\033[34m'
    CYAN='\033[36m'
    YELLOW='\033[33m'
    GREEN='\033[32m'
    RED='\033[31m'
    MAGENTA='\033[35m'
    GRAY='\033[90m'
    WHITE='\033[97m'

    # Format issues hierarchically: parents first, then their children indented
    format_issues() {
      bd list --json --all 2>/dev/null | ${pkgs.jq}/bin/jq -r '
        # Color codes
        def reset: "\u001b[0m";
        def bold: "\u001b[1m";
        def dim: "\u001b[2m";
        def blue: "\u001b[34m";
        def cyan: "\u001b[36m";
        def yellow: "\u001b[33m";
        def green: "\u001b[32m";
        def red: "\u001b[31m";
        def magenta: "\u001b[35m";
        def gray: "\u001b[90m";
        def white: "\u001b[97m";

        # Color based on type
        def type_color:
          if . == "epic" then magenta + bold
          elif . == "feature" then cyan
          elif . == "bug" then red
          elif . == "task" then blue
          elif . == "chore" then gray
          else white
          end;

        # Color based on priority
        def priority_color:
          if . <= 1 then red + bold
          elif . == 2 then yellow
          else green
          end;

        # Color based on status
        def status_icon:
          if . == "in_progress" then yellow + "●" + reset
          elif . == "blocked" then red + "✗" + reset
          elif . == "closed" then green + "✓" + reset
          elif . == "deferred" then gray + "◌" + reset
          else dim + "○" + reset
          end;

        # Sort by priority for stable ordering (reversed for display)
        sort_by(.priority // 2, .id) | reverse |

        # Separate into parents (no parent) and children (has parent)
        . as $all |
        ($all | map(select(.parent == null or .parent == ""))) as $parents |
        ($all | map(select(.parent != null and .parent != "")) | group_by(.parent) | map({key: .[0].parent, value: .}) | from_entries) as $children |

        # Output parents, each followed by their children (children first for reversed display)
        $parents[] |
        (($children[.id] // []) | sort_by(.priority // 2) | reverse | .[] |
          gray + "  └─ " + reset +
          (.status | status_icon) + " " +
          blue + .id + reset + "\t" +
          white + .title + reset + "\t" +
          ((.type // "task") | . as $t | type_color + $t + reset) + "\t" +
          ((.priority // 2) | . as $p | priority_color + "P" + ($p | tostring) + reset)
        ),
        (.status | status_icon) + " " +
        bold + cyan + .id + reset + "\t" +
        bold + white + .title + reset + "\t" +
        ((.type // "task") | . as $t | type_color + $t + reset) + "\t" +
        ((.priority // 2) | . as $p | priority_color + "P" + ($p | tostring) + reset)
      ' || true
    }

    issues=$(format_issues)

    if [[ -z "$issues" ]]; then
      echo -e "''${YELLOW}No beads found''${RESET}"
      read -n 1 -s -r -p "Press any key to close..."
      exit 0
    fi

    selection=$(echo "$issues" | ${pkgs.fzf}/bin/fzf \
      --ansi \
      --delimiter '\t' \
      --with-nth '1,2,3,4' \
      --preview 'id=$(echo {} | sed "s/\x1b\[[0-9;]*m//g" | sed "s/^[[:space:]]*└─[[:space:]]*//" | sed "s/^[○●✗✓◌][[:space:]]*//" | cut -f1); bd show "$id"' \
      --preview-window 'right:60%:wrap:border-left' \
      --header $'ENTER: implement │ DEL: delete │ ESC: cancel' \
      --header-first \
      --border=rounded \
      --border-label=' Beads ' \
      --border-label-pos=3 \
      --color='header:yellow,border:blue,label:cyan:bold' \
      --color='pointer:cyan,marker:cyan,spinner:cyan' \
      --color='hl:yellow:bold,hl+:yellow:bold:reverse' \
      --pointer='▶' \
      --marker='✓' \
      --expect 'enter,del,delete' \
      2>/dev/null) || exit 0

    [[ -z "$selection" ]] && exit 0

    key=$(head -1 <<< "$selection")
    line=$(sed -n '2p' <<< "$selection")

    [[ -z "$line" ]] && exit 0

    # Strip ANSI codes, indent/tree chars, and status icons, then extract ID
    clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[[:space:]]*└─[[:space:]]*//' | sed 's/^[○●✗✓◌][[:space:]]*//')
    id=$(echo "$clean_line" | cut -f1)
    title=$(echo "$clean_line" | cut -f2)

    case "$key" in
      enter)
        details=$(bd show "$id" 2>/dev/null || echo "")
        # Split window and start claude in plan mode
        ${pkgs.tmux}/bin/tmux split-window -h \
          "claude --permission-mode plan \"Implement bead $id: $title\""
        ;;
      del|delete)
        bd delete "$id"
        exec "$0"  # Re-run to show updated list
        ;;
    esac
  '';
in
{
  config = lib.mkIf config.programs.tmux.enable {
    home.packages = [
      pkgs.tmux-sessionizer
      bd-picker
    ];

    xdg = {
      enable = true;
      configFile."tms/config.toml".text = ''
        default_session = "Main"

        [picker_colors]
        highlight_color = "#de8f78"
        border_color = "#6791c9"

        [[search_dirs]]
        path = "/home/sgiath"
        depth = 1

        [[search_dirs]]
        path = "/home/sgiath/develop"
        depth = 2
      '';
    };

    programs.tmux = {
      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "xterm-256color";
      baseIndex = 1;
      clock24 = true;
      mouse = true;
      historyLimit = 10000;
      extraConfig = ''
        unbind c
        bind c display-popup -E "tms"
        unbind s
        bind s display-popup -E "tms switch"

        # Beads picker
        unbind b
        bind b display-popup -E -w 80% -h 80% "${bd-picker}/bin/bd-picker"

        # New window
        bind m new-window

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
        setw -g window-status-format "#[bg=$bg,fg=$fg] #W "
        setw -g window-status-current-format "#[fg=$yellow,bg=$bg]#[bg=$yellow,fg=$bg]#W#[fg=$yellow,bg=$bg]"

        # Auto-rename windows to git branch name
        set-option -g automatic-rename off
        set-option -g allow-rename off

        # Rename command - used by multiple hooks
        set -g @branch-rename 'run-shell "sleep 0.1; tmux rename-window \"$(cd #{pane_current_path} && git branch --show-current 2>/dev/null || basename #{pane_current_path})\"" 2>/dev/null'

        set-hook -g after-select-pane 'run-shell "tmux rename-window \"$(cd #{pane_current_path} && git branch --show-current 2>/dev/null || basename #{pane_current_path})\"" 2>/dev/null'
        set-hook -g pane-focus-in 'run-shell "tmux rename-window \"$(cd #{pane_current_path} && git branch --show-current 2>/dev/null || basename #{pane_current_path})\"" 2>/dev/null'
        set-hook -g after-new-window 'run-shell "sleep 0.2; tmux rename-window \"$(cd #{pane_current_path} && git branch --show-current 2>/dev/null || basename #{pane_current_path})\"" 2>/dev/null'
        set-hook -g session-created 'run-shell "sleep 0.3; tmux rename-window \"$(cd #{pane_current_path} && git branch --show-current 2>/dev/null || basename #{pane_current_path})\"" 2>/dev/null'
        set-hook -g client-attached 'run-shell "sleep 0.1; tmux rename-window \"$(cd #{pane_current_path} && git branch --show-current 2>/dev/null || basename #{pane_current_path})\"" 2>/dev/null'

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
        # {
        #   plugin = tmuxPlugins.resurrect;
        #   extraConfig = ''
        #     set -g @resurrect-strategy-nvim 'session'
        #   '';
        # }
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
  };
}
