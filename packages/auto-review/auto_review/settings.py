"""Settings: Nix defaults merged with the overrides the UI writes. An override wins over the default."""

import json
import os
import re
import tempfile
import threading
from copy import deepcopy
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from .note import DEFAULT_TEMPLATE

CONTRACT = "auto-review/v1"

GLOBAL_DEFAULTS = {
    "paused": False,
    "dry_run": False,
    "poll_interval_seconds": 60,
    "threshold": 5,
    "request_changes_threshold": 30,
    "auto_settle": True,
    "note_template": None,  # None: note.DEFAULT_TEMPLATE, filled in by `effective`
    "reviewer": {"provider": "codex", "model": "gpt-6.1-sol", "effort": "high"},
    "max_concurrent": 3,
    "max_launches_per_day": None,
    "review_timeout_minutes": 120,
    "timezone": "Europe/Prague",
    "quiet_hours": {"enabled": False, "start": "22:00", "end": "07:00"},
    "notify": {"desktop": True, "ntfy_url": None},
    "repos": {},
}

RULE_DEFAULTS = {
    "review_requested": True,
    "include_authors": [],
    "exclude_authors": [],
    "require_labels": [],
    "exclude_labels": [],
    "skip_drafts": True,
    "wait_for_pipeline": True,
}

REPO_DEFAULTS = {
    "enabled": True,
    "checkout": None,
    "t3_project": None,
    "context": "",
    "threshold": None,
    "request_changes_threshold": None,
    "reviewer": None,
    "approval": "when_clean",
    "rules": RULE_DEFAULTS,
}


class SettingsError(ValueError):
    def __init__(self, field: str, message: str):
        super().__init__(f"{field}: {message}")
        self.field = field
        self.message = message


def effective(defaults: dict, overrides: dict) -> dict:
    """GLOBAL_DEFAULTS < `defaults` (Nix) < `overrides` (UI), merged per key; repos merge by id and each repo is
    filled from REPO_DEFAULTS, with `forge` and `path` taken from its id (`gitlab:a/b`, `github:o/r`)."""
    result = _merge(_merge(deepcopy(GLOBAL_DEFAULTS), _without(defaults, "repos")), _without(overrides, "repos"))
    repos = {}
    for repo_id in {**(defaults.get("repos") or {}), **(overrides.get("repos") or {})}:
        forge, _, path = repo_id.partition(":")
        repo = _merge(deepcopy(REPO_DEFAULTS), {"forge": forge, "path": path})
        repo = _merge(repo, (defaults.get("repos") or {}).get(repo_id) or {})
        repos[repo_id] = _merge(repo, (overrides.get("repos") or {}).get(repo_id) or {})
    result["repos"] = repos
    if result["note_template"] is None:
        result["note_template"] = DEFAULT_TEMPLATE
    return result


def apply_patch(overrides: dict, patch: dict, defaults: dict) -> dict:
    """New overrides: `patch` deep-merged into `overrides`, a `null` removing that override (for a repo id, the
    whole repo's overrides). The result's effective settings are validated; raises SettingsError."""
    result = _patch(deepcopy(overrides), patch)
    validate(effective(defaults, result))
    return result


def validate(settings: dict) -> None:
    """Raise SettingsError naming the dotted field (`repos.<id>.threshold`) of the first invalid value."""
    for name in ("paused", "dry_run", "auto_settle"):
        _check(name, isinstance(settings[name], bool), "must be true or false")
    _positive("threshold", settings["threshold"])
    _positive("request_changes_threshold", settings["request_changes_threshold"])
    _check("poll_interval_seconds", _int(settings["poll_interval_seconds"]) and settings["poll_interval_seconds"] >= 15,
           "must be at least 15")
    _positive("max_concurrent", settings["max_concurrent"])
    cap = settings["max_launches_per_day"]
    _check("max_launches_per_day", cap is None or (_int(cap) and cap >= 0), "must be empty or 0 or more")
    _positive("review_timeout_minutes", settings["review_timeout_minutes"])
    _check("note_template", settings["note_template"] is None or isinstance(settings["note_template"], str),
           "must be text")
    try:
        ZoneInfo(settings["timezone"])
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        raise SettingsError("timezone", "is not a known time zone") from None
    quiet = settings["quiet_hours"]
    _check("quiet_hours.enabled", isinstance(quiet["enabled"], bool), "must be true or false")
    for name in ("start", "end"):
        _check(f"quiet_hours.{name}", isinstance(quiet[name], str) and bool(CLOCK.match(quiet[name])),
               "must be HH:MM")
    _check("notify.desktop", isinstance(settings["notify"]["desktop"], bool), "must be true or false")
    ntfy = settings["notify"]["ntfy_url"]
    _check("notify.ntfy_url", ntfy is None or (isinstance(ntfy, str) and ntfy.startswith("https://")),
           "must be empty or an https:// URL")
    _reviewer("reviewer", settings["reviewer"])
    for repo_id, repo in settings["repos"].items():
        _repo(f"repos.{repo_id}", repo_id, repo)


def repo_view(settings: dict, repo_id: str) -> dict:
    """One repo with `threshold`, `request_changes_threshold` and `reviewer` resolved against the globals."""
    repo = deepcopy(settings["repos"][repo_id])
    for name in ("threshold", "request_changes_threshold"):
        if repo[name] is None:
            repo[name] = settings[name]
    if repo["reviewer"] is None:
        repo["reviewer"] = deepcopy(settings["reviewer"])
    return repo


class SettingsFile:
    """The defaults file (read-only, from Nix) and the overrides file (written atomically by `patch`)."""

    def __init__(self, defaults_path: Path, overrides_path: Path):
        self._defaults = json.loads(Path(defaults_path).read_text())
        self._path = Path(overrides_path)
        self._overrides = json.loads(self._path.read_text()) if self._path.exists() else {}
        self._lock = threading.Lock()
        self._effective = effective(self._defaults, self._overrides)
        validate(self._effective)

    def get(self) -> dict:
        return self._effective

    def defaults(self) -> dict:
        return deepcopy(self._defaults)

    def overrides(self) -> dict:
        return deepcopy(self._overrides)

    def patch(self, patch: dict) -> dict:
        """Apply and save; returns the new effective settings."""
        with self._lock:
            overrides = apply_patch(self._overrides, patch, self._defaults)
            self._path.parent.mkdir(parents=True, exist_ok=True)
            handle = tempfile.NamedTemporaryFile(
                "w", dir=self._path.parent, prefix=".overrides.", suffix=".tmp", delete=False
            )
            try:
                with handle:
                    json.dump(overrides, handle, indent=2, sort_keys=True)
                    handle.write("\n")
                    handle.flush()
                    os.fsync(handle.fileno())
                os.replace(handle.name, self._path)
            except BaseException:
                Path(handle.name).unlink(missing_ok=True)
                raise
            self._overrides = overrides
            self._effective = effective(self._defaults, overrides)
            return self._effective


CLOCK = re.compile(r"^([01]\d|2[0-3]):[0-5]\d$")
APPROVALS = ("never", "when_clean")
REPO_ID = re.compile(r"^(gitlab:[\w.-]+(/[\w.-]+)+|github:[\w.-]+/[\w.-]+)$")


def _repo(field: str, repo_id: str, repo: dict) -> None:
    _check(field, bool(REPO_ID.match(repo_id)), "id must be gitlab:<group/project> or github:<owner/repo>")
    _check(f"{field}.enabled", isinstance(repo["enabled"], bool), "must be true or false")
    for name in ("checkout", "t3_project"):
        _check(f"{field}.{name}", isinstance(repo[name], str) and bool(repo[name].strip()), "is required")
    _check(f"{field}.context", isinstance(repo["context"], str), "must be text")
    for name in ("threshold", "request_changes_threshold"):
        if repo[name] is not None:
            _positive(f"{field}.{name}", repo[name])
    if repo["reviewer"] is not None:
        _reviewer(f"{field}.reviewer", repo["reviewer"])
    _check(f"{field}.approval", repo["approval"] in APPROVALS, f"must be one of {', '.join(APPROVALS)}")
    rules = repo["rules"]
    for name in ("review_requested", "skip_drafts", "wait_for_pipeline"):
        _check(f"{field}.rules.{name}", isinstance(rules[name], bool), "must be true or false")
    for name in ("include_authors", "exclude_authors", "require_labels", "exclude_labels"):
        value = rules[name]
        _check(f"{field}.rules.{name}", isinstance(value, list) and all(isinstance(v, str) and v for v in value),
               "must be a list of names")


def _reviewer(field: str, reviewer: dict) -> None:
    _check(field, isinstance(reviewer, dict), "must be an object")
    for name in ("provider", "model", "effort"):
        _check(f"{field}.{name}", isinstance(reviewer.get(name), str) and bool(reviewer[name]), "is required")


def _positive(field: str, value) -> None:
    _check(field, _int(value) and value >= 1, "must be a whole number of 1 or more")


def _int(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _check(field: str, ok: bool, message: str) -> None:
    if not ok:
        raise SettingsError(field, message)


def _merge(base: dict, extra: dict) -> dict:
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            base[key] = _merge(base[key], value)
        else:
            base[key] = deepcopy(value)
    return base


# FIXME: `null` in a patch always means "drop the override", so the UI cannot override a non-null Nix value with
# null (a Nix repo threshold or reviewer back to "use the global one", a Nix daily cap back to unlimited). A
# distinct "set to null" marker would fix it once such a Nix default exists.
def _patch(base: dict, patch: dict) -> dict:
    for key, value in patch.items():
        if value is None:
            base.pop(key, None)
        elif isinstance(value, dict):
            merged = _patch(base.get(key) if isinstance(base.get(key), dict) else {}, value)
            if merged or not value:
                base[key] = merged
            else:
                base.pop(key, None)
        else:
            base[key] = deepcopy(value)
    return base


def _without(data: dict, key: str) -> dict:
    return {k: v for k, v in (data or {}).items() if k != key}
