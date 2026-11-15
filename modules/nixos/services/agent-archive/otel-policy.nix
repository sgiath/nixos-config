# Which OpenTelemetry the agent archive keeps, as collector processors. The
# local otel-agent (modules/home/agents/archive.nix) applies it before data
# leaves a host, and Vesta's collector (agent-archive.nix) again for hosts
# not yet switched and for queues filled before the policy existed.
#
# Kept: what otel.sql reads and what explains failures. Claude traces (request
# and tool timing), and the harness logs except Codex SSE events other than
# completions and errors (90% of all logs were streaming deltas). Dropped:
# other services (dev apps export to the default OTLP endpoint, :4318),
# Codex traces, every metric, and prompt, tool and response content, which
# archive.raw already holds.
{ lib }:
let
  services = [
    "claude-code"
    "codex-app-server"
    "codex_exec"
    "codex_cli_rs"
    # Codex run by T3 Code under its own service name.
    "T3 Code"
  ];
  contentKeys = [
    "content"
    "prompt"
    "prompt_text"
    "user_prompt"
    "tool_parameters"
    "tool_input"
    "tool_output"
    "arguments"
    "output"
    "response"
    "input"
    "gen_ai.input.messages"
    "gen_ai.output.messages"
    "gen_ai.prompt"
    "gen_ai.completion"
    "gen_ai.tool.call.arguments"
    "gen_ai.tool.call.result"
  ];

  any = conds: "(${lib.concatStringsSep " or " conds})";
  present = key: ''(attributes["${key}"] != nil and attributes["${key}"] != "")'';
  harness = any (map (s: ''resource.attributes["service.name"] == "${s}"'') services);
  # Error events carry no consistent severity or kind; any of these marks one.
  sseKept = any (
    [
      ''attributes["event.kind"] == "response.completed"''
      ''(attributes["event.kind"] != nil and IsMatch(attributes["event.kind"], "(?i)(error|fail|incomplete|cancel|retry)"))''
      "severity_number >= 17"
      ''attributes["success"] == false''
      ''attributes["success"] == "false"''
    ]
    ++ map present [
      "error.message"
      "error"
      "error.type"
      "exception.type"
      "exception.message"
    ]
  );
  # The OTTL string unescapes once, so a literal dot is `\\.` in its source.
  keyPattern = lib.concatMapStringsSep "|" (lib.replaceStrings [ "." ] [ "\\\\." ]) contentKeys;
  stripContent = ''delete_matching_keys(attributes, "^(${keyPattern})$")'';
in
{
  inherit services contentKeys;

  # Errors are logged and the record passes: a failing condition must not
  # reject a batch, which the sending queue would retry forever.
  processors = {
    "filter/agents" = {
      error_mode = "ignore";
      traces.span = [ ''resource.attributes["service.name"] != "claude-code"'' ];
      metrics.metric = [ "true" ];
      logs.log_record = [
        "not ${harness}"
        ''attributes["event.name"] == "codex.sse_event" and not ${sseKept}''
      ];
    };
    "transform/content" = {
      error_mode = "ignore";
      log_statements = [
        {
          context = "log";
          statements = [
            stripContent
            ''set(body, "")''
          ];
        }
      ];
      trace_statements = [
        {
          context = "span";
          statements = [ stripContent ];
        }
      ];
    };
  };

  pipelines = [
    "filter/agents"
    "transform/content"
  ];
}
