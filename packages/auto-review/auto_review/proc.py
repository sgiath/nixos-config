"""Run external commands with a timeout and a readable failure that never echoes stdin."""

import json
import subprocess
from typing import Any


class CommandError(Exception):
    pass


def run(cmd: list[str], *, input: str | None = None, timeout: int = 120, cwd=None, ok_codes=(0,)) -> str:
    try:
        result = subprocess.run(cmd, input=input, capture_output=True, text=True, timeout=timeout, cwd=cwd)
    except subprocess.TimeoutExpired as error:
        raise CommandError(f"{_show(cmd)} timed out after {timeout}s") from error
    except OSError as error:
        raise CommandError(f"{_show(cmd)} could not start: {error}") from error
    if result.returncode not in ok_codes:
        detail = (result.stderr or result.stdout).strip()[-1500:]
        raise CommandError(f"{_show(cmd)} exited {result.returncode}: {detail}")
    return result.stdout


def run_json(cmd: list[str], **kwargs) -> Any:
    out = run(cmd, **kwargs)
    try:
        return json.loads(out)
    except ValueError as error:
        raise CommandError(f"{_show(cmd)} printed invalid JSON: {out[:300]!r}") from error


def concat_pages(out: str) -> list:
    """`--paginate` prints one JSON array per page back to back."""
    decoder = json.JSONDecoder()
    items: list = []
    index = 0
    while index < len(out):
        while index < len(out) and out[index].isspace():
            index += 1
        if index >= len(out):
            break
        page, index = decoder.raw_decode(out, index)
        if not isinstance(page, list):
            raise ValueError(f"expected a JSON list per page, got {type(page).__name__}")
        items.extend(page)
    return items


def _show(cmd: list[str]) -> str:
    return " ".join(cmd[:4]) + (" …" if len(cmd) > 4 else "")
