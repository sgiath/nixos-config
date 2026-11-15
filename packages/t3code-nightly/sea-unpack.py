"""Unpack a Node single executable application so its code can be patched.

Writes the main script, every asset and a `node --build-sea` config that
rebuilds an equivalent executable. The blob layout follows SeaSerializer in
node's src/node_sea.cc; anything this script cannot reproduce (snapshot, code
cache, VFS) fails instead of being dropped.

Usage: sea-unpack.py <executable> <output directory> <rebuilt executable path>
"""

import json
import struct
import sys
from pathlib import Path

MAGIC = 0x143DA20
DISABLE_WARNING, USE_SNAPSHOT, USE_CODE_CACHE, ASSETS, EXEC_ARGV = (1 << i for i in range(5))
UNSUPPORTED = ~(DISABLE_WARNING | ASSETS | EXEC_ARGV) & 0xFFFFFFFF
EXEC_ARGV_EXTENSION = ["none", "env", "cli"]
MAIN_FORMAT = ["commonjs", "module"]


class Reader:
    def __init__(self, data, offset):
        self.data, self.offset = data, offset

    def number(self, fmt):
        value = struct.unpack_from(fmt, self.data, self.offset)[0]
        self.offset += struct.calcsize(fmt)
        return value

    def bytes(self):
        size = self.number("<Q")
        if self.offset + size > len(self.data):
            raise ValueError("string runs past the end of the file")
        value = self.data[self.offset : self.offset + size]
        self.offset += size
        return value


def parse(data, offset):
    reader = Reader(data, offset)
    if reader.number("<I") != MAGIC:
        raise ValueError("no magic")
    flags = reader.number("<I")
    if flags & UNSUPPORTED:
        raise ValueError(f"unsupported flags {flags:#x}")
    extension, main_format = reader.number("<B"), reader.number("<B")
    reader.bytes()  # code path, unused by --build-sea
    blob = {
        "flags": flags,
        "execArgvExtension": EXEC_ARGV_EXTENSION[extension],
        "mainFormat": MAIN_FORMAT[main_format],
        "main": reader.bytes(),
        "assets": {},
        "execArgv": [],
    }
    if flags & ASSETS:
        for _ in range(reader.number("<Q")):
            key = reader.bytes().decode()
            if key in ("", ".", "..") or "/" in key:
                raise ValueError(f"unexpected asset name {key!r}")
            blob["assets"][key] = reader.bytes()
    if flags & EXEC_ARGV:
        blob["execArgv"] = [reader.bytes().decode() for _ in range(reader.number("<Q"))]
    return blob


def find_blob(data):
    # The magic also occurs in node's own code; only the blob parses.
    blobs, offset = [], data.find(struct.pack("<I", MAGIC))
    while offset >= 0:
        try:
            blobs.append(parse(data, offset))
        except (ValueError, IndexError, struct.error, UnicodeDecodeError):
            pass
        offset = data.find(struct.pack("<I", MAGIC), offset + 1)
    if len(blobs) != 1:
        sys.exit(f"sea-unpack: expected one SEA blob, found {len(blobs)}")
    return blobs[0]


def main(executable, out, output):
    blob = find_blob(Path(executable).read_bytes())
    out = Path(out).resolve()
    (out / "assets").mkdir(parents=True)
    main_path = out / ("main.mjs" if blob["mainFormat"] == "module" else "main.cjs")
    main_path.write_bytes(blob["main"])
    assets = {}
    for key, content in blob["assets"].items():
        (out / "assets" / key).write_bytes(content)
        assets[key] = str(out / "assets" / key)
    config = {
        "main": str(main_path),
        "output": output,
        "mainFormat": blob["mainFormat"],
        "disableExperimentalSEAWarning": bool(blob["flags"] & DISABLE_WARNING),
        "useSnapshot": False,
        "useCodeCache": False,
        "execArgvExtension": blob["execArgvExtension"],
        "execArgv": blob["execArgv"],
        "assets": assets,
    }
    (out / "sea-config.json").write_text(json.dumps(config, indent=2) + "\n")
    print(f"sea-unpack: {main_path.name} and assets {sorted(assets)} in {out}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
