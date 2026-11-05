{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.sgiath.agents.enable {
    # Vercel Labs fx coding agent (https://github.com/vercel-labs/fx); also used by the evals harness.
    home.packages = [ pkgs.llm-agents.fx ];
  };
}
