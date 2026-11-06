# Models the agent tools offer through CLIProxyAPI (cliproxy.nix).
# `personal` (bare and OpenCode Go) is every tool's global catalog;
# Remote projects get the Claude and GPT ones as remote/<model> plus
# `remoteOnly`, the Remote LiteLLM models that have no personal counterpart. `protocol` is the wire API each tool uses for the model
# where it can choose (fx only speaks chat completions). Limits come from the
# installed Codex/Pi model catalogs and xAI's Grok 4.7 guide; `effort` lists
# the reasoning efforts the model accepts ([] when unknown).
{
  personal = [
    {
      id = "claude-opus-5-5";
      name = "Claude Opus 5.5";
      protocol = "messages";
      context = 1000000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "claude-sonnet-5-5";
      name = "Claude Sonnet 5.5";
      protocol = "messages";
      context = 1000000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "claude-haiku-5-5";
      name = "Claude Haiku 5.5";
      protocol = "messages";
      context = 1000000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "claude-fable-5-1";
      name = "Claude Fable 5.1";
      protocol = "messages";
      context = 1000000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "xhigh"
        "max"
      ];
    }
    {
      id = "gpt-6.1-sol";
      name = "GPT-6.1 Sol";
      protocol = "responses";
      context = 272000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "gpt-6.1-terra";
      name = "GPT-6.1 Terra";
      protocol = "responses";
      context = 500000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "gpt-6-astra";
      name = "GPT-6 Astra";
      protocol = "responses";
      context = 272000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "gpt-6-luna";
      name = "GPT-6 Luna";
      protocol = "responses";
      context = 272000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "grok-4.7";
      name = "Grok 4.7";
      protocol = "chat";
      context = 500000;
      # xAI states no separate output limit; tools send this as max tokens.
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
      ];
    }
    {
      id = "muse-wonder-full-1.0";
      name = "Muse Wonder Full 1.0";
      protocol = "chat";
      context = 1007997;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "muse-spark-1.3";
      name = "Muse Spark 1.3";
      protocol = "chat";
      context = 1048576;
      output = 131072;
      input = [
        "text"
        "image"
      ];
      effort = [
        "minimal"
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "opencode-go/kimi-k3.1-pro";
      name = "Kimi K3.1 Pro (Go)";
      protocol = "chat";
      context = 1048576;
      output = 131072;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "high"
        "max"
      ];
    }
    {
      id = "opencode-go/glm-5.3";
      name = "GLM-5.3 (Go)";
      protocol = "chat";
      context = 1000000;
      output = 131072;
      input = [ "text" ];
      effort = [
        "low"
        "high"
        "max"
      ];
    }
    {
      id = "opencode-go/minimax-m3.1-flash";
      name = "MiniMax M3.1 Flash (Go)";
      protocol = "chat";
      context = 1000000;
      output = 512000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "opencode-go/qwen3.8-max";
      name = "Qwen3.8 Max (Go)";
      protocol = "chat";
      context = 1000000;
      output = 131072;
      input = [
        "text"
        "image"
      ];
      effort = [ ];
    }
    {
      id = "opencode-go/gemini-4-argon";
      name = "Gemini 4 Argon (Go)";
      protocol = "chat";
      context = 1048576;
      output = 65536;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
      ];
    }
  ];

  remoteOnly = [
    {
      id = "remote/gpt-5.6-luna";
      name = "GPT-5.6 Luna (Remote)";
      protocol = "responses";
      # Limits as Remote LiteLLM reports them.
      context = 922000;
      output = 128000;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];
    }
    {
      id = "remote/gemini-4-argon";
      name = "Gemini 4 Argon (Remote)";
      protocol = "chat";
      context = 1048576;
      output = 65536;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "medium"
        "high"
      ];
    }
    {
      id = "remote/gemini-3.8-flash";
      name = "Gemini 3.8 Flash (Remote)";
      protocol = "chat";
      context = 1048576;
      output = 65536;
      input = [
        "text"
        "image"
      ];
      effort = [ ];
    }
    {
      id = "remote/kimi-k3.1-pro";
      name = "Kimi K3.1 Pro (Remote)";
      protocol = "chat";
      context = 1048576;
      output = 131072;
      input = [
        "text"
        "image"
      ];
      effort = [
        "low"
        "high"
        "max"
      ];
    }
  ];
}
