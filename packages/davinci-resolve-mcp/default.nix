{
  lib,
  fetchFromGitHub,
  python3,
  runCommand,
  makeWrapper,
  ffmpeg,
}:
let
  version = "4.15.3";
  src = fetchFromGitHub {
    owner = "samuelgursky";
    repo = "davinci-resolve-mcp";
    tag = "v${version}";
    hash = "sha256-9Gw+y+Q3Mk72jM3C//dAfX34D5rbryo1DX1JzeGvlaE=";
  };

  # FIXME: Resolve MCP requires SDK >=1.30,<2. Remove this override when
  # pinned nixpkgs provides 1.30; SDK 2 removes mcp.server.fastmcp.
  mcp = python3.pkgs.mcp.overridePythonAttrs {
    version = "1.30.0";
    src = fetchFromGitHub {
      owner = "modelcontextprotocol";
      repo = "python-sdk";
      tag = "v1.30.0";
      hash = "sha256-EkmTqsK+vBJcURuwFkhtNJMFgtzgw/7Cd+Fpav4P/ko=";
    };
  };
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
