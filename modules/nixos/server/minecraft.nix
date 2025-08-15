{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.minecraft-server.enable) {
    environment.systemPackages = with pkgs; [
      jdk8
      jdk21
    ];

    services.minecraft-server = {
      eula = true;
      declarative = true;

      # https://minecraft.wiki/w/Server.properties#Java_Edition
      serverProperties = {
        # easy
        difficulty = 1;
        # survival
        gamemode = 0;
        server-port = 25565;
        max-players = 10;
        online-mode = false;
      };
    };
  };
}
