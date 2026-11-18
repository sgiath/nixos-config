"""TOML <-> JSON for the activation merges in cliproxy.nix.

`to-json FILE` prints FILE's TOML as JSON. `from-json FILE` reads the merged
JSON on stdin and prints FILE's TOML with only the changed values replaced,
so comments and formatting elsewhere survive. When that edit would not read
back as the merged JSON, it prints a plain serialization instead and warns.
"""

import json
import os
import sys
import tomllib

import tomli_w
import tomlkit


def _plain(value):
    return value.unwrap() if hasattr(value, "unwrap") else value


def _same(a, b):
    """Equal including type: Python takes true == 1 and 1.0 == 1."""
    return json.dumps(_plain(a), sort_keys=True) == json.dumps(b, sort_keys=True)


def _patch(doc, new):
    for key in [key for key in doc if key not in new]:
        del doc[key]
    for key, value in new.items():
        if isinstance(value, dict) and isinstance(doc.get(key), dict):
            _patch(doc[key], value)
        elif key not in doc or not _same(doc[key], value):
            doc[key] = value


def to_json(text):
    try:
        return json.dumps(tomllib.loads(text))
    except TypeError as error:
        raise SystemExit(f"toml-json: no JSON form for this TOML ({error})") from None


def from_json(original, new):
    doc = tomlkit.parse(original)
    _patch(doc, new)
    text = tomlkit.dumps(doc)
    try:
        if _same(tomllib.loads(text), new):
            return text
    except tomllib.TOMLDecodeError:
        pass
    print("toml-json: an in-place edit would change other values; rewriting without comments", file=sys.stderr)
    return tomli_w.dumps(new)


def main(argv):
    original = ""
    if os.path.exists(argv[2]):
        with open(argv[2], newline="") as f:
            original = f.read()
    if argv[1] == "to-json":
        sys.stdout.write(to_json(original))
    else:
        sys.stdout.write(from_json(original, json.load(sys.stdin)))


if __name__ == "__main__":
    main(sys.argv)
