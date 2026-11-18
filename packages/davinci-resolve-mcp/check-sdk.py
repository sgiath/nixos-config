"""Fail when Resolve MCP's mcp requirement no longer matches the bundled SDK."""

import sys

from packaging.requirements import Requirement

RECORD = "UPSTREAM-WORKAROUNDS.md#davinci-resolve-mcp-sdk-version"

requirements, bundled, nixpkgs = sys.argv[1:]
with open(requirements) as lines:
    reqs = [Requirement(line) for line in (raw.split("#")[0].strip() for raw in lines) if line]
specs = [req.specifier for req in reqs if req.name == "mcp" and (req.marker is None or req.marker.evaluate())]

if len(specs) != 1:
    sys.exit(f"Resolve MCP has {len(specs)} applicable mcp requirements, expected one; see {RECORD}")
spec = specs[0]
if bundled not in spec:
    sys.exit(f"Resolve MCP requires mcp{spec}, but the bundled SDK is {bundled}; see {RECORD}")
if nixpkgs in spec:
    sys.exit(f"Resolve MCP now accepts nixpkgs' mcp {nixpkgs} (mcp{spec}): check whether the bundled SDK can go; see {RECORD}")
