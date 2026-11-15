{
  config,
  lib,
  pkgs,
  ...
}:
let
  userKeys = {
    GITHUB_TOKEN = "github_token";
    CLIPROXY_API_KEY = "cliproxy_api_key";
  };
  keyFiles = pkgs.writeText "user-api-key-paths.json" (
    builtins.toJSON (lib.mapAttrs (_: key: config.sops.secrets.${key}.path) userKeys)
  );
  apiKeyWrapper = pkgs.writeShellScriptBin "with-api-keys" ''
    exec ${lib.getExe pkgs.python3} ${./load-api-keys.py} ${keyFiles} "$@"
  '';
in
{
  config = lib.mkIf config.sgiath.enable {
    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      gnupg.sshKeyPaths = [ ];
      secrets = lib.genAttrs (lib.unique (builtins.attrValues userKeys)) (_: {
        owner = "sgiath";
        mode = "0400";
      });
      templates.nix-access-tokens = {
        owner = "sgiath";
        mode = "0400";
        content = ''
          access-tokens = github.com=${config.sops.placeholder.github_token}
        '';
      };
    };

    home-manager.extraSpecialArgs = { inherit apiKeyWrapper; };
  };
}
