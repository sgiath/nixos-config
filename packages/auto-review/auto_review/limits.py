"""Recognise a run stopped by a provider usage limit, and when the limit resets.

T3's MCP read reports the failure only as text (no structured reset time), for example
"You've hit your individual spend limit · your weekly limit resets Nov 5, 7pm (UTC)" or "… resets 12:20pm (UTC)".
"""

import re
from datetime import UTC, datetime, timedelta

LIMIT = re.compile(r"spend limit|usage limit|rate limit reached", re.IGNORECASE)
RESET = re.compile(
    r"resets (?:([A-Z][a-z]{2}) (\d{1,2}), )?(\d{1,2})(?::(\d{2}))?\s*([ap]m)\s*\(UTC\)", re.IGNORECASE
)
MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]


def is_limit(text: str | None) -> bool:
    """Whether `text` reports a provider usage limit."""
    return bool(text and LIMIT.search(text))


def reset_time(text: str | None, now: datetime) -> datetime | None:
    """The UTC time the usage limit in `text` resets; None when the text names none that can be read."""
    match = RESET.search(text or "")
    if not match or (match.group(1) and match.group(1).lower() not in MONTHS):
        return None
    month, day, hour, minute, half = match.groups()
    hour, minute = int(hour), int(minute or 0)
    if not 1 <= hour <= 12 or minute > 59:
        return None
    hour = hour % 12 + (12 if half.lower() == "pm" else 0)
    if month:
        return _nearest_future(now, MONTHS.index(month.lower()) + 1, int(day), hour, minute)
    reset = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    return reset if reset > now else reset + timedelta(days=1)


def _nearest_future(now: datetime, month: int, day: int, hour: int, minute: int) -> datetime | None:
    """The message gives no year: take the dated time closest to now, which for a limit is the coming one; None for a
    date no year has."""
    candidates = []
    for year in (now.year - 1, now.year, now.year + 1):
        try:
            candidates.append(datetime(year, month, day, hour, minute, tzinfo=UTC))
        except ValueError:
            continue
    return min(candidates, key=lambda candidate: abs(candidate - now), default=None)
