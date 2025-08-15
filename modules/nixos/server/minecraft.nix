{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.minecraft-server.enable) {
    services.minecraft-server = {
      # package = pkgs.minecraft-server_1_21_8;
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