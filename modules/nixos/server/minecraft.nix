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
        environment = {
          JAVA_PATH = "${pkgs.jdk8}/lib/openjdk/bin/java";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "/data/minecraft/nomi/launch.sh";
          WorkingDirectory = "/data/minecraft/nomi";
        };
      };

      # GT: New Horizons (port 25567)
      minecraft-gtnh = {
        enable = true;
        description = "Minecraft GTNH server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          JAVA_PATH = "${pkgs.jdk21}/lib/openjdk/bin/java";
        };
        serviceConfig = {
          Type = "simple";
          ExecStart = "/data/minecraft/gtnh/startserver-java9.sh";
          WorkingDirectory = "/data/minecraft/gtnh";
        };
      };
    };
  };
}
