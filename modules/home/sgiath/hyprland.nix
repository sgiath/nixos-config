{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hyprland/color.nix
    ./hyprland/general.nix
    ./hyprland/keybindings.nix
    ./hyprland/layout.nix
    ./hyprland/looks.nix
    ./hyprland/monitors.nix
    ./hyprland/rules.nix
  ];

  options.programs.hyprland = {
    enable = lib.mkEnableOption "hyprland";
  };

  config = lib.mkIf config.programs.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      xwayland.enable = true;

      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [ "--all" ];
      };

      settings = {
        group.groupbar.font_size = 14;

        workspace = [
          "special:special, gapsout:30"
          "1,monitor:DP-1,default:true,persistent:true"
          "2,monitor:DP-3,default:true,persistent:true"
          "3,monitor:DP-3,persistent:true"
          "4,monitor:DP-1,persistent:true"
          "5,monitor:DP-3,persistent:true"
          "6,monitor:DP-1,persistent:true"
          "7,monitor:DP-3,persistent:true"
          "8,monitor:DP-3,persistent:true"
          "9,monitor:DP-3,persistent:true"
          "10,monitor:DP-2,default:true,gapsin:0,gapsout:0,border:false,persistent:true"
        ];
      };
    };
    stylix.targets = {
      hyprland.enable = false;
      fuzzel.enable = false;
    };

    gtk = pkgs.lib.mkForce {
      enable = true;
      theme = {
        package = pkgs.flat-remix-gtk;
        name = "Flat-Remix-GTK-Grey-Darkest";
      };
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };
    };

    home.packages = [ pkgs.grim ];

    programs.wofi = {
      enable = true;
      settings = {
        mode = "drun";
        prompt = "";
        insensitive = true;
      };
    };

    services = {
      mako.enable = true;
      hyprpolkitagent.enable = true;
    };
  };
}
