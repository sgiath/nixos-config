{
  lib,
  python3Packages,
  fetchgit,
  runCommand,
}:

let
  version = "1.0.3";

  src = fetchgit {
    url = "https://projects.blender.org/lab/blender_mcp.git";
    rev = "v${version}";
    hash = "sha256-pYeByO4Oi5eyynsJhGVd1vBWXHvhGn+Y5LGit6Kazlw=";
  };
in
python3Packages.buildPythonApplication {
  pname = "blender-mcp";
  inherit version src;
  pyproject = true;

  sourceRoot = "${src.name}/mcp";

  build-system = [ python3Packages.setuptools ];

  dependencies =
    with python3Packages;
    [
      docutils
      mcp
      pyyaml
    ]
    ++ mcp.optional-dependencies.cli;

  pythonImportsCheck = [ "blmcp" ];

  # The Blender side of the bridge, laid out as a `BLENDER_SYSTEM_EXTENSIONS`
  # root: Blender loads `<root>/system/<id>` as `bl_ext.system.<id>`.
  passthru.addon = runCommand "blender-mcp-addon-${version}" { } ''
    mkdir -p $out/system
    cp -r ${src}/addon/blender_mcp_addon $out/system/mcp
  '';

  meta = {
    description = "Blender Lab MCP server for Blender's Python API";
    homepage = "https://www.blender.org/lab/mcp-server/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "blender-mcp";
  };
}
