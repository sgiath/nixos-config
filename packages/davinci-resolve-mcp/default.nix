{
  lib,
  fetchFromGitHub,
  python3,
  runCommand,
  makeWrapper,
  ffmpeg,
}:
let
  version = "4.18.0";
  src = fetchFromGitHub {
    owner = "samuelgursky";
    repo = "davinci-resolve-mcp";
    tag = "v${version}";
    hash = "sha256-LjcNyYUMN28qj/VvYyClVvOAmPw5UZVHGA8xuFS/bCQ=";
  };

  # FIXME: Resolve MCP requires SDK >=1.30,<2 because server.py imports
  # mcp.server.fastmcp, which SDK 2 removed; nixpkgs ships SDK 2. Build SDK 1
  # here, not as an override of the 2.x recipe, whose dependencies and tests
  # do not apply. Remove it when upstream Resolve MCP supports SDK 2.
  mcp = python3.pkgs.buildPythonPackage (finalAttrs: {
    pname = "mcp";
    version = "1.30.0";
    pyproject = true;
    __structuredAttrs = true;

    src = fetchFromGitHub {
      owner = "modelcontextprotocol";
      repo = "python-sdk";
      tag = "v${finalAttrs.version}";
      hash = "sha256-EkmTqsK+vBJcURuwFkhtNJMFgtzgw/7Cd+Fpav4P/ko=";
    };

    build-system = with python3.pkgs; [
      hatchling
      uv-dynamic-versioning
    ];

    dependencies =
      with python3.pkgs;
      [
        anyio
        httpx
        httpx-sse
        jsonschema
        pydantic
        pydantic-settings
        pyjwt
        python-multipart
        sse-starlette
        starlette
        typing-extensions
        typing-inspection
        uvicorn
      ]
      ++ pyjwt.optional-dependencies.crypto;

    optional-dependencies = with python3.pkgs; {
      cli = [
        python-dotenv
        typer
      ];
      rich = [ rich ];
      ws = [ websockets ];
    };

    pythonImportsCheck = [
      "mcp"
      "mcp.server.fastmcp"
    ];

    nativeCheckInputs =
      with python3.pkgs;
      [
        dirty-equals
        inline-snapshot
        pytest-asyncio
        pytest-examples
        pytest-xdist
        pytestCheckHook
        requests
      ]
      ++ lib.flatten (builtins.attrValues finalAttrs.passthru.optional-dependencies);

    pytestFlags = [ "-Wignore::pytest.PytestRemovedIn10Warning" ];

    # The nixpkgs SDK 1.29 recipe's exclusions, plus one flaky HTTP test.
    disabledTests = [
      # attempts to run the package manager uv
      "test_command_execution"
      # ExceptionGroup: unhandled errors in a TaskGroup
      "test_lifespan_cleanup_executed"
      "test_tool_progress"
      # process-tree cleanup assertions fail in the sandbox
      "test_basic_child_process_cleanup"
      "test_nested_process_tree"
      "test_early_parent_exit"
      "test_stdin_close_triggers_cleanup"
      # pytest.PytestUnraisableExceptionWarning
      "test_list_tools_returns_all_tools"
      "test_resource_template_client_interaction"
      # Flaky: https://github.com/modelcontextprotocol/python-sdk/pull/1171
      "test_notification_validation_error"
      # Flaky: httpx.ConnectError: All connection attempts failed
      "test_sse_security_"
      "test_streamable_http_"
      "test_streamablehttp_"
      # Flaky with SDK 1.30: McpError('Session terminated') on initialize
      "test_client_includes_protocol_version_header_after_init"
      # timing assertion too tight under load
      "test_messages_are_executed_concurrently"
    ];
  });
  python = python3.withPackages (ps: [
    mcp
    ps.numpy
    ps.pyyaml
  ]);
in
runCommand "davinci-resolve-mcp-${version}"
  {
    pname = "davinci-resolve-mcp";
    inherit version;
    nativeBuildInputs = [ makeWrapper ];
    passthru = { inherit python; };
    meta = {
      description = "MCP server for DaVinci Resolve's scripting API";
      homepage = "https://github.com/samuelgursky/davinci-resolve-mcp";
      license = lib.licenses.mit;
      mainProgram = "davinci-resolve-mcp";
      platforms = lib.platforms.unix;
    };
  }
  ''
    mkdir -p $out/share $out/bin
    cp -r ${src} $out/share/davinci-resolve-mcp
    chmod u+w $out/share/davinci-resolve-mcp
    mkdir -p $out/share/davinci-resolve-mcp/logs
    # Upstream's empty log setting installs a NullHandler. Configure stderr
    # before running it so systemd captures startup and connection failures.
    cat > $out/share/davinci-resolve-mcp/launch.py <<'PY'
    import logging
    import os
    import runpy
    from pathlib import Path

    if not os.environ.get("RESOLVE_MCP_LOG_FILE"):
        logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
        logging.getLogger("mcp").setLevel(logging.WARNING)
    runpy.run_path(str(Path(__file__).parent / "src/server.py"), run_name="__main__")
    PY
    makeWrapper ${python}/bin/python $out/bin/davinci-resolve-mcp \
      --add-flags "$out/share/davinci-resolve-mcp/launch.py" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --set DAVINCI_RESOLVE_MCP_UPDATE_MODE never \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg ]} \
      --set-default RESOLVE_MCP_LOG_FILE ""
  ''
