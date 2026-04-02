{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.services.hermes-agent.enable {
    services.hermes-agent = {
      settings.model.default = "anthropic/claude-sonnet-4";
      environmentFiles = [ "/home/sgiath/.hermes_env" ];
      addToSystemPackages = true;
    };
  };
}
