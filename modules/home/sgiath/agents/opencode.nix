{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  opencode = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # opencode = (
  #   inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode.overrideAttrs (old: {
  #     preBuild = (old.preBuild or "") + ''
  #       substituteInPlace packages/opencode/src/cli/cmd/generate.ts \
  #         --replace-fail 'const prettier = await import("prettier")' 'const prettier: any = { format: async (s: string) => s }' \
  #         --replace-fail 'const babel = await import("prettier/plugins/babel")' 'const babel = {}' \
  #         --replace-fail 'const estree = await import("prettier/plugins/estree")' 'const estree = {}'
  #       substituteInPlace package.json \
  #         --replace-fail '"packageManager": "bun@1.3.13"' '"packageManager": "bun@${pkgs.bun.version}"'
  #     '';
  #   })
  # );
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    programs.opencode = {
      enable = true;
      package = opencode;
      enableMcpIntegration = true;
      context = ./AGENTS.md;
      agents = ./agents;
      commands = ./commands;
      skills = ./skills;
      settings = {
        # theme = "orng";
        autoupdate = false;
        permission = {
          bash = {
            "*" = "allow";
            "aws *" = "ask";
            "kubectl exec *" = "ask";
          };
          read = {
            "/nix/store/**" = "allow";
          };
          edit = {
            "/tmp/**" = "allow";
            "~/**" = "allow";
          };
          external_directory = {
            "/tmp/**" = "allow";
            "~/**" = "allow";
          };
        };
        server = {
          hostname = "0.0.0.0";
          mdns = true;
          cors = [
            "http://localhost:4096"
            "http://192.168.1.7:4096"
            "http://localhost:4097"
            "http://192.168.1.7:4097"
          ];
        };
        experimental = {
          batch_tool = true;
        };
      };

      web = {
        enable = true;
      };
    };
    stylix.targets.opencode.enable = false;

    # aliases
    programs.zsh.shellAliases = {
      oc = "OPENCODE_DISABLE_CLAUDE_CODE=true OPENCODE_ENABLE_EXA=1 ${lib.getExe opencode}";
    };
  };
}
