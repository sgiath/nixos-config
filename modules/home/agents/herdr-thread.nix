{
  config,
  lib,
  pkgs,
  ...
}:
let
  herdr-thread = pkgs.writeShellApplication {
    name = "herdr-thread";
    runtimeInputs = [
      config.programs.herdr.package
      config.programs.git.package
      config.programs.worktrunk.package
      pkgs.jq
    ];
    text = builtins.readFile ./herdr-thread.sh;
  };
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    home.packages = [ herdr-thread ];
  };
}
