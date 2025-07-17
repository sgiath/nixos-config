{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.sgiath.docker = {
    enable = lib.mkEnableOption "Docker";
  };

  config = lib.mkIf config.sgiath.docker.enable {
    virtualisation = {
      docker = {
        enable = true;
        extraPackages = with pkgs; [
          docker-credential-helpers
          amazon-ecr-credential-helper
        ];
      };

      podman = {
        enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    users.users.sgiath.extraGroups = [ "docker" ];
    
    environment.systemPackages = with pkgs; [
      docker-credential-helpers
      amazon-ecr-credential-helper
    ];
  };
}
