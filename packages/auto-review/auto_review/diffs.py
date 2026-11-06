"""Diff lines a comment can attach to."""

import re

from .models import Anchor, FileDiff

HUNK = re.compile(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@")


class _File:
    def __init__(self, diff: FileDiff):
        self.old_path, self.new_path = diff.old_path, diff.new_path
        self.added: set[int] = set()
        self.removed: set[int] = set()
        self.new_to_old: dict[int, int] = {}
        self.old_to_new: dict[int, int] = {}
        old = new = 0
        for text in diff.patch.splitlines():
            if hunk := HUNK.match(text):
                old, new = int(hunk.group(1)), int(hunk.group(2))
            elif text.startswith("+"):
                self.added.add(new)
                new += 1
            elif text.startswith("-"):
                self.removed.add(old)
                old += 1
            elif text.startswith(" ") or text == "":
                self.new_to_old[new] = old
                self.old_to_new[old] = new
                old += 1
                new += 1
            # "\ No newline at end of file" and anything else moves neither side.


class DiffIndex:
    """Per file: added new lines, removed old lines, and context lines (new -> old), keyed by new and old path."""

    def __init__(self, diffs: list[FileDiff]):
        self._files: dict[str, _File] = {}
        for diff in diffs:
            entry = _File(diff)
            self._files[diff.new_path] = entry
            self._files.setdefault(diff.old_path, entry)

    def anchor(self, file: str, side: str, line: int) -> Anchor | None:
        """The anchor for `line` on `side` of `file` (its new path, or old path for a removed file), or None when
        that line is not in the diff. `new` accepts added and context lines; `old` accepts removed and context
        lines."""
        entry = self._files.get(file)
        if entry is None:
            return None
        paths = (entry.old_path, entry.new_path)
        if side == "new":
            if line in entry.added:
                return Anchor(*paths, "new", None, line)
            if line in entry.new_to_old:
                return Anchor(*paths, "new", entry.new_to_old[line], line)
        elif side == "old":
            if line in entry.removed:
                return Anchor(*paths, "old", line, None)
            if line in entry.old_to_new:
                return Anchor(*paths, "old", line, entry.old_to_new[line])
        return None
