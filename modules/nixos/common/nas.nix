{ config, lib, ... }:
{
  config = lib.mkIf (config.sgiath.enable && config.sgiath.nas.enable) {
    sops = {
      secrets.synology_password = {
        owner = "root";
        mode = "0400";
      };
      templates.nas-credentials = {
        owner = "root";
        mode = "0400";
        content = ''
          username=sgiath
          password=${config.sops.placeholder.synology_password}
        '';
      };
    };

    # Every member uses the same NAS identity across all shares, including homes.
    users.groups.nas.members = [
      "sgiath"
    ]
    ++ lib.optional config.services.audiobookshelf.enable config.services.audiobookshelf.user
    ++ lib.optional config.services.jellyfin.enable config.services.jellyfin.user
    ++ lib.optional config.services.transmission.enable config.services.transmission.user;

    fileSystems =
      lib.mapAttrs'
        (
          path: share:
          lib.nameValuePair "/nas/${path}" {
            device = "//192.168.1.4/${share}";
            fsType = "cifs";
            options = [
              "vers=3.0"
              "credentials=${config.sops.templates.nas-credentials.path}"
              "uid=sgiath"
              "gid=nas"
              "forceuid"
              "forcegid"
              "nounix"
              "file_mode=0660"
              "dir_mode=0770"
              "_netdev"
              "x-systemd.automount"
              "noauto"
            ]
            # Without systemd activation the secrets are installed by the
            # activation script before systemd starts, so no unit to wait on.
            ++ lib.optional config.sops.useSystemdActivation "x-systemd.requires=sops-install-secrets.service";
          }
        )
        {
          homes = "homes";
          movies = "Movies";
          music = "Music";
          series = "Series";
          downloads = "Downloads";
        };
  };
}
