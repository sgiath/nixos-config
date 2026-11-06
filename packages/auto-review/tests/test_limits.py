"""Provider reset messages retain their date, or roll a clock time forward."""

import unittest
from datetime import UTC, datetime

from auto_review.limits import reset_time


class ResetTimeTests(unittest.TestCase):
    def test_weekly_limit_uses_the_reported_date(self):
        message = "You've hit your individual spend limit · your weekly limit resets Nov 5, 7pm (UTC)"
        now = datetime(2026, 11, 2, 20, 24, tzinfo=UTC)

        self.assertEqual(reset_time(message, now), datetime(2026, 11, 5, 19, tzinfo=UTC))

    def test_clock_only_reset_rolls_to_the_next_day(self):
        message = "You've hit your individual spend limit · resets 7pm (UTC)"
        now = datetime(2026, 11, 2, 20, 24, tzinfo=UTC)

        self.assertEqual(reset_time(message, now), datetime(2026, 11, 3, 19, tzinfo=UTC))
