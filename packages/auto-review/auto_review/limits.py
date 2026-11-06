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
# FIXME: a limit message without a readable reset waits this long and is then continued; if the limit still holds,
# the next stop starts another wait. A structured reset time from T3's MCP read would remove the guess.
UNKNOWN_RESET_WAIT = timedelta(minutes=30)


def reset_time(text: str | None, now: datetime) -> datetime | None:
    """The UTC time the limit resets when `text` reports a usage limit; None for any other failure."""
    if not text or not LIMIT.search(text):
        return None
    match = RESET.search(text)
    if not match or (match.group(1) and match.group(1).lower() not in MONTHS):
        return now + UNKNOWN_RESET_WAIT
    month, day, hour, minute, half = match.groups()
    hour = int(hour) % 12 + (12 if half.lower() == "pm" else 0)
    minute = int(minute or 0)
    if month:
        return _nearest_future(now, MONTHS.index(month.lower()) + 1, int(day), hour, minute)
    reset = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    return reset if reset > now else reset + timedelta(days=1)


def _nearest_future(now: datetime, month: int, day: int, hour: int, minute: int) -> datetime:
    """The message gives no year: take the dated time closest to now, which for a limit is the coming one."""
    candidates = []
    for year in (now.year - 1, now.year, now.year + 1):
        try:
            candidates.append(datetime(year, month, day, hour, minute, tzinfo=UTC))
        except ValueError:
            continue
    return min(candidates, key=lambda candidate: abs(candidate - now))
