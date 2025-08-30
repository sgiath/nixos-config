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
  config = lib.mkIf (config.sgiath.server.enable) {
    # for starting new packs on the server and testing
    environment.systemPackages = with pkgs; [ jdk21 ];

    systemd.services = {

      # vanilla (port 25565)
      minecraft-vanilla = {
        enable = true;
        description = "Minecraft Vanilla server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${pkgs.jdk21}/lib/openjdk/bin/java -server -Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar paper-1.21.8-50.jar --nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/vanilla";
        };
      };

      # nomifactory (port 25566)
      minecraft-nomi = {
        enable = true;
        description = "Minecraft Nomifactory server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${pkgs.jdk8}/lib/openjdk/bin/java -server -Xms4G -Xmx4G -jar forge-1.12.2-14.23.5.2860.jar nogui";
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
        script = "${pkgs.jdk21}/lib/openjdk/bin/java -server -Xms4G -Xmx6G -Dfml.queryResult=confirm -Dfml.readTimeout=180 @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/gtnh";
        };
      };

      # All the Mods 10 (port 25568)
      minecraft-atm10 = {
        enable = true;
        description = "Minecraft ATM 10 server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${pkgs.jdk21}/lib/openjdk/bin/java @user_jvm_args.txt @libraries/net/neoforged/neoforge/21.1.201/unix_args.txt nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/atm10";
        };
      };
    };

    services = {
      nginx.virtualHosts."minecraft.sgiath.dev" = {
        # SSL
        onlySSL = true;
        kTLS = true;

        # ACME
        enableACME = true;
        acmeRoot = null;

        # QUIC
        http3_hq = true;
        quic = true;

        locations."/" = {
          proxyWebsockets = true;
          proxyPass = "http://127.0.0.1:8804";
        };
      };
    };
  };
}
