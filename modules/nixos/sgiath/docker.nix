{
  config,
  lib,
  ...
}:
{
  options.sgiath.docker = {
    enable = lib.mkEnableOption "Docker";
  };

  config = lib.mkIf config.sgiath.docker.enable {
    virtualisation.docker.enable = false;
    virtualisation.podman = {
      enable = true;
    };
    # users.users.sgiath.extraGroups = [ "docker" ];
  };
}
