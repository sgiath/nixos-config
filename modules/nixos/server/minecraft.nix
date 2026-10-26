{
  config,
  lib,
  pkgs,
  ...
}:
# let
#   operators = {
#     # online accounts
#     SgiathMC = "a3072618-d0b9-3091-ba3d-f6607f5cd37c";

#     # offline accounts
#     Sgiath = "8441ebbf-4c37-3cc3-bc05-32a06694f504";
#     Kuba = "821b0f4a-cdd3-371d-8ab7-98882924f39c";
#     kihitomi = "cb24a33e-407c-3625-955b-7535ed160d3a";
#     HorkyJohny = "d30a8ff0-6759-3889-9852-a1c6dcf3501f";
#   };
# in
{
  config = lib.mkIf (config.sgiath.roles.server.enable) {
    # for starting new packs on the server and testing
    environment.systemPackages = with pkgs; [ zulu25 ];

    users.groups.minecraft-family = { };
    users.users.minecraft-family = {
      isSystemUser = true;
      group = "minecraft-family";
      home = "/data/minecraft/family";
    };
    systemd.tmpfiles.rules = [
      "d /data/minecraft/family 0750 minecraft-family minecraft-family -"
      "Z /data/minecraft/family - minecraft-family minecraft-family -"
    ];

    # The family server's console, so stopping it can type `stop` (as nixpkgs' minecraft-server does)
    systemd.sockets.minecraft-family = {
      bindsTo = [ "minecraft-family.service" ];
      socketConfig = {
        ListenFIFO = "/run/minecraft-family.stdin";
        SocketMode = "0600";
        SocketUser = "minecraft-family";
        SocketGroup = "minecraft-family";
        RemoveOnStop = true;
        FlushPending = true;
      };
    };

    systemd.services = {

      # vanilla (port 25565)
      minecraft-vanilla = {
        enable = false;
        description = "Minecraft Vanilla server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${lib.getExe pkgs.zulu25} -server -Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar paper-1.21.8-50.jar --nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/vanilla";
        };
      };

      # nomifactory (port 25566)
      minecraft-nomi = {
        enable = false;
        description = "Minecraft Nomifactory server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${lib.getExe pkgs.zulu8} -server -Xms4G -Xmx4G -jar forge-1.12.2-14.23.5.2860.jar nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/nomi";
        };
      };

      # GT: New Horizons (port 25567)
      minecraft-gtnh = {
        enable = false;
        description = "Minecraft GTNH server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${lib.getExe pkgs.zulu25} -server -Xms6G -Xmx6G -Dfml.queryResult=confirm -Dfml.readTimeout=180 @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/gtnh";
        };
      };

      # Family 1.7.10 (port 25569): vanilla progression with GTNH's tools, from gtnh-ai's
      # `tools/family-pack`; unpack its server zip into the working directory to install or update it
      minecraft-family = {
        enable = true;
        description = "Minecraft Family 1.7.10 server";
        after = [
          "network.target"
          "minecraft-family.socket"
        ];
        requires = [ "minecraft-family.socket" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig = {
          ConditionPathExists = "/data/minecraft/family/lwjgl3ify-forgePatches.jar";
          # A server that keeps crashing at start stops retrying
          StartLimitIntervalSec = "15min";
          StartLimitBurst = 3;
        };
        script = "exec ${lib.getExe pkgs.zulu25} -server -Xms6G -Xmx6G -Dfml.readTimeout=180 @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui";
        # SIGTERM races the server thread (no "Saving worlds", an empty crash report): type `stop` and wait
        # for Java to save and exit
        preStop = ''
          if [ -n "''${MAINPID:-}" ] && kill -0 "$MAINPID" 2>/dev/null; then
            echo stop > /run/minecraft-family.stdin
            while kill -0 "$MAINPID" 2>/dev/null; do sleep 1; done
          fi
        '';
        serviceConfig = {
          User = "minecraft-family";
          Group = "minecraft-family";
          WorkingDirectory = "/data/minecraft/family";
          StandardInput = "socket";
          StandardOutput = "journal";
          StandardError = "journal";
          # The global 5 s default is too short for saving a modded world with Distant Horizons
          TimeoutStopSec = "10min";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };

      # All the Mods 10 (port 25568)
      minecraft-atm10 = {
        enable = false;
        description = "Minecraft ATM 10 server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = "${lib.getExe pkgs.zulu25} @user_jvm_args.txt @libraries/net/neoforged/neoforge/21.1.201/unix_args.txt nogui";
        serviceConfig = {
          WorkingDirectory = "/data/minecraft/atm10";
        };
      };
    };

    # services = {
    #   nginx.virtualHosts."minecraft.sgiath.dev" = {
    #     # SSL
    #     onlySSL = true;
    #     kTLS = true;

    #     # ACME
    #     enableACME = true;
    #     acmeRoot = null;

    #     locations."/" = {
    #       proxyWebsockets = true;
    #       proxyPass = "http://127.0.0.1:8804";
    #     };
    #   };
    # };
  };
}
