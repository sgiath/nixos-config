{
  config,
  lib,
  pkgs,
  ...
}:
let
  operators = {
    # online accounts
    SgiathMC = "a3072618-d0b9-3091-ba3d-f6607f5cd37c";

    # offline accounts
    Sgiath = "8441ebbf-4c37-3cc3-bc05-32a06694f504";
    Kuba = "821b0f4a-cdd3-371d-8ab7-98882924f39c";
    kihitomi = "cb24a33e-407c-3625-955b-7535ed160d3a";
  };
in
{
  config = lib.mkIf (config.sgiath.server.enable && config.services.minecraft-servers.enable) {
    # for starting new packs on the server and testing
    environment.systemPackages = with pkgs; [ jdk21 ];

    # vanila server
    services.minecraft-servers = {
      eula = true;
      managementSystem = {
        tmux.enable = true;
        # systemd-socket.enable = true;
      };

      servers = {
        vanila = {
          enable = true;
          inherit operators;

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
