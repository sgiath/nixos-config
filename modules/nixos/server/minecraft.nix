{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.minecraft-server.enable) {

    # vanila server
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

    systemd.services = {

      # nomifactory (port 25566)
      minecraft-nomi = {
        enable = true;
        description = "Minecraft Nomifactory server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${pkgs.jdk8}/lib/openjdk/bin/java -server -Xms4096M -Xmx4096M -jar forge-1.12.2-14.23.5.2860.jar nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/nomi";
        };
      };

      # GT: New Horizons (port 25567)
      minecraft-gtnh = {
        enable = true;
        description = "Minecraft GTNH server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${pkgs.jdk21}/lib/openjdk/bin/java -server -Xms6G -Xmx6G -Dfml.readTimeout=180 @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/gtnh";
        };
      };
    };
  };
}
