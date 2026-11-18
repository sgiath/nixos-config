"""Provider reset messages retain their date, or roll a clock time forward."""

import unittest
from datetime import UTC, datetime

from auto_review import limits
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

    def test_limit_without_a_readable_reset_has_no_reset_time(self):
        message = "You've hit your usage limit. Try again later."

        self.assertTrue(limits.is_limit(message))
        self.assertIsNone(reset_time(message, datetime(2026, 11, 2, 20, 24, tzinfo=UTC)))
        self.assertFalse(limits.is_limit("thread ended: crashed"))
