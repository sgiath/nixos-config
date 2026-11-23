{
  config,
  lib,
  pkgs,
  ...
}:
let
  url = config.sgiath.agents.cliproxyUrl;
  jq = lib.getExe pkgs.jq;
  catalogIds = map (m: m.id) (import ./cliproxy-models.nix).personal;

  # toml-json/toml_json.py; its tests run as part of the build.
  tomlJson =
    let
      python = pkgs.python3.withPackages (ps: [
        ps.tomli-w
        ps.tomlkit
      ]);
    in
    pkgs.runCommandLocal "toml-json" { } ''
      PYTHONDONTWRITEBYTECODE=1 ${lib.getExe python} -I -m unittest discover \
        -s ${./toml-json} -t ${./toml-json}
      install -Dm755 ${./toml-json/toml_json.py} $out
      sed -i '1i#!${lib.getExe python} -I' $out
    '';

  # Remove the CLIProxy model overrides and non-Grok helper defaults that
  # cliproxy.nix used to merge into ~/.grok/config.toml so Grok uses its
  # native xAI login and catalog directly. Matches the exact URL and env_key
  # the old generator wrote, preserves unrelated custom models, and also
  # cleans stale catalog references left in allowed_models or helper slots.
  cleanupFilter = ''
    ((.model // {}) | to_entries | map(
      select(
        (.value | type == "object")
        and .value.base_url == ($url + "/v1")
        and .value.env_key == "CLIPROXY_API_KEY"
      )
      | .key
    )) as $removed
    | (if ($removed | length) > 0 then
         (.model |= with_entries(select(.key | IN($removed[]) | not)))
         | if (.model | length) == 0 then del(.model) else . end
       else . end)
    | ((.model // {}) | keys) as $kept
    | ((($removed + $catalog) | unique) - $kept) as $managed
    | if (.models.allowed_models? | type) == "array"
         and (($removed | length) > 0
              or (.models.allowed_models | any((startswith("grok-") | not) and IN($managed[])))) then
        ((.models.allowed_models) - $managed) as $left
        | if ($left | length) == 0 then del(.models.allowed_models) else .models.allowed_models = $left end
      else . end
    | reduce ("default", "web_search", "session_summary", "image_description", "prompt_suggestion") as $slot (
        .;
        if (.models[$slot]? | type) == "string"
           and ((.models[$slot] | startswith("grok-")) | not)
           and (.models[$slot] | IN($managed[]))
        then del(.models[$slot]) else . end
      )
    | if (.ui.fork_secondary_model? | type) == "string"
         and ((.ui.fork_secondary_model | startswith("grok-")) | not)
         and (.ui.fork_secondary_model | IN($managed[]))
      then del(.ui.fork_secondary_model) else . end
  '';
in
{
  config = lib.mkIf config.sgiath.agents.enable {
    # Grok loads ~/.claude/CLAUDE.md and ~/.claude/skills/ automatically via
    # Claude compatibility (`grok inspect`), so do not also link ~/.grok/AGENTS.md
    # (Grok loads every matching rules file in each home directory).
    home.activation.grokNative = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      f="$HOME/.grok/config.toml"
      if [ -f "$f" ]; then
        old=$(cat "$f")
        if new=$(set -o pipefail; ${tomlJson} to-json "$f" \
          | ${jq} --arg url ${lib.escapeShellArg url} \
              --argjson catalog ${lib.escapeShellArg (builtins.toJSON catalogIds)} \
              ${lib.escapeShellArg cleanupFilter} \
          | ${tomlJson} from-json "$f"); then
          if [ "$new" != "$old" ]; then
            run ${pkgs.coreutils}/bin/tee "$f" <<<"$new" >/dev/null
          fi
        else
          echo "grok: cannot clean CLIProxy settings from $f; left unchanged" >&2
        fi
      fi
    '';
  };
}
