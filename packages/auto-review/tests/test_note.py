import unittest

from auto_review.models import Note, Thread
from auto_review.note import VARIABLES, comment_body, marker, own_markers, render
from tests.fakes import finding


class NoteTest(unittest.TestCase):
    def test_all_known_variables_render(self):
        values = {name: f"value-{name}" for name in VARIABLES}
        values.update(number=7, frequency=1, severity=5, score=5, threshold=5)
        rendered, unknown = render(" | ".join("{" + name + "}" for name in VARIABLES), values)
        self.assertEqual(rendered, " | ".join(str(values[name]) for name in VARIABLES))
        self.assertEqual(unknown, [])

    def test_unknown_words_preserved_and_reported_once_in_first_seen_order(self):
        rendered, unknown = render("{zebra} {title} {alpha} {zebra}", {"title": "Defect"})
        self.assertEqual(rendered, "{zebra} Defect {alpha} {zebra}")
        self.assertEqual(unknown, ["zebra", "alpha"])

    def test_nonvariable_braces_are_literal(self):
        template = 'JSON: {"key": 3}; {} {a-b} {two words}'
        self.assertEqual(render(template, {}), (template, []))

    def test_comment_body_ends_with_marker_after_note_and_finding(self):
        key = "gitlab:team/service:7:head:base:main"
        body = comment_body("Review by @{reviewer}", finding(), {"reviewer": "sgiath"}, key)
        expected_marker = f"<!-- auto-review:v1 key={key} finding=SR-1 -->"
        self.assertEqual(marker(key, "SR-1"), expected_marker)
        self.assertEqual(body, f"Review by @sgiath\n\nUse the current value.\n\n{expected_marker}")

    def test_own_markers_ignore_other_authors_and_match_self_case_insensitively(self):
        own = "<!-- auto-review:v1 key=review-one finding=SR-1 -->"
        foreign = "<!-- auto-review:v1 key=review-two finding=SR-2 -->"
        note = Note("SGIATH", "My comment\n\n" + own, "n1")
        threads = [Thread("t1", False, (note,)),
                   Thread("t2", False, (Note("alice", foreign, "n2"),))]
        self.assertEqual(own_markers(threads, "sgiath"), {own: ("t1", note)})
