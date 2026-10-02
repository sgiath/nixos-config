{ lib, ... }:
{
  imports = [
    ./audio.nix
    ./bitcoin.nix
    ./blender.nix
    ./browsers.nix
    ./chat.nix
    ./editors.nix
    ./email.nix
  ];

  options.sgiath.programs = {
    audio.enable = lib.mkEnableOption "audio";
    bitcoin.enable = lib.mkEnableOption "bitcoin apps";
    blender.enable = lib.mkEnableOption "Blender, exposed to agents over MCP when agents are enabled";
    browsers.enable = lib.mkEnableOption "web browsers";
    chat.enable = lib.mkEnableOption "communication apps";
    editors.enable = lib.mkEnableOption "my editors";
    email.enable = lib.mkEnableOption "Email Client";
  };
}
