import json
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

from auto_review.diffs import DiffIndex
from auto_review.models import FileDiff, Thread, Verdict
from auto_review.verdict import VerdictError, decide, load
from tests.fakes import BASE, DIFFS, HEAD, finding, raw_finding, raw_verdict


class VerdictLoadTest(unittest.TestCase):
    def load_data(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "verdict.json"
            path.write_text(json.dumps(data))
            return load(path, review_id=1, attempt=1, head_sha=HEAD, base_sha=BASE)

    def test_valid_verdict_loads_and_recomputes_supplied_score(self):
        row = raw_finding(frequency=2, severity=3)
        row["score"] = 99
        result = self.load_data(raw_verdict(findings=[row]))
        self.assertEqual(result.status, "complete")
        self.assertEqual(result.findings[0].score, 6)
        self.assertEqual(result.findings[0].file, "src/new.py")

    def test_rejects_wrong_schema_review_attempt_head_or_base(self):
        for field, value in (("schema", "spain-review/v1"), ("review_id", 2), ("attempt", 2),
                             ("head_sha", "c" * 40), ("base_sha", "d" * 40)):
            with self.subTest(field=field), self.assertRaises(VerdictError):
                self.load_data({**raw_verdict(), field: value})

    def test_previous_attempt_cannot_satisfy_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "verdict.json"
            path.write_text(json.dumps(raw_verdict(attempt=1)))
            with self.assertRaises(VerdictError):
                load(path, review_id=1, attempt=2, head_sha=HEAD, base_sha=BASE)

    def test_missing_file_and_malformed_json_are_verdict_errors(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "verdict.json"
            with self.assertRaises(VerdictError):
                load(path, review_id=1, attempt=1, head_sha=HEAD, base_sha=BASE)
            path.write_text("{broken")
            with self.assertRaises(VerdictError):
                load(path, review_id=1, attempt=1, head_sha=HEAD, base_sha=BASE)

    def test_score_inputs_are_integers_one_through_ten(self):
        for field in ("frequency", "severity"):
            for value in (0, 11, True, "5", 1.5):
                with self.subTest(field=field, value=value), self.assertRaises(VerdictError):
                    row = raw_finding()
                    row[field] = value
                    self.load_data(raw_verdict(findings=[row]))

    def test_score_boundaries_are_accepted(self):
        result = self.load_data(raw_verdict(findings=[raw_finding(frequency=10, severity=1)]))
        self.assertEqual(result.findings[0].score, 10)

    def test_invalid_sides_and_nonpositive_or_noninteger_lines_rejected(self):
        for field, value in (("side", "left"), ("side", "NEW"), ("line", 0),
                             ("line", -1), ("line", True), ("line", "11")):
            with self.subTest(field=field, value=value), self.assertRaises(VerdictError):
                row = raw_finding()
                row[field] = value
                self.load_data(raw_verdict(findings=[row]))

    def test_finding_ids_are_unique_and_well_formed(self):
        with self.assertRaises(VerdictError):
            self.load_data(raw_verdict(findings=[raw_finding(), raw_finding()]))
        with self.assertRaises(VerdictError):
            self.load_data(raw_verdict(findings=[raw_finding(id="not-an-id")]))

    def test_required_finding_text_is_not_blank(self):
        for field in ("title", "file", "body"):
            with self.subTest(field=field), self.assertRaises(VerdictError):
                row = raw_finding()
                row[field] = " "
                self.load_data(raw_verdict(findings=[row]))

    def test_invalid_status_and_array_types_are_rejected(self):
        for field, value in (("status", "almost"), ("findings", {}),
                             ("not_reviewed", "src/new.py"), ("injection_attempts", {})):
            with self.subTest(field=field), self.assertRaises(VerdictError):
                self.load_data({**raw_verdict(), field: value})

    def test_missing_required_arrays_are_rejected(self):
        for field in ("findings", "not_reviewed", "injection_attempts"):
            with self.subTest(field=field):
                data = raw_verdict()
                del data[field]
                with self.assertRaises(VerdictError):
                    self.load_data(data)


class DiffIndexTest(unittest.TestCase):
    def setUp(self):
        self.index = DiffIndex(DIFFS)

    def test_added_line_on_renamed_file_has_only_new_line(self):
        anchor = self.index.anchor("src/new.py", "new", 11)
        self.assertIsNotNone(anchor)
        self.assertEqual((anchor.old_path, anchor.new_path, anchor.side, anchor.old_line, anchor.new_line),
                         ("src/old.py", "src/new.py", "new", None, 11))

    def test_removed_line_uses_old_path_and_old_line(self):
        anchor = self.index.anchor("src/old.py", "old", 11)
        self.assertIsNotNone(anchor)
        self.assertEqual((anchor.old_path, anchor.new_path, anchor.old_line, anchor.new_line),
                         ("src/old.py", "src/new.py", 11, None))

    def test_context_line_carries_both_numbers_on_either_side(self):
        for path, side, line in (("src/new.py", "new", 13), ("src/old.py", "old", 12)):
            with self.subTest(side=side):
                anchor = self.index.anchor(path, side, line)
                self.assertIsNotNone(anchor)
                self.assertEqual((anchor.old_line, anchor.new_line, anchor.side), (12, 13, side))

    def test_file_line_or_side_outside_diff_has_no_anchor(self):
        for path, side, line in (("missing.py", "new", 11), ("src/new.py", "new", 99),
                                 ("src/new.py", "old", 13), ("src/new.py", "new", 0)):
            with self.subTest(path=path, side=side, line=line):
                self.assertIsNone(self.index.anchor(path, side, line))

    def test_multiple_hunks_and_no_newline_marker_do_not_shift_lines(self):
        index = DiffIndex([FileDiff("x", "x", "@@ -1 +1 @@\n-a\n+b\n\\ No newline at end of file\n"
                                   "@@ -20,0 +21,1 @@\n+c\n")])
        self.assertEqual(index.anchor("x", "new", 21).new_line, 21)
        self.assertIsNone(index.anchor("x", "new", 2))


class DecisionTest(unittest.TestCase):
    def decision(self, findings=(), threads=(), **fields):
        verdict = Verdict("complete", None, "Reviewed", tuple(findings), (), ())
        return decide(replace(verdict, **fields), threshold=5, index=DiffIndex(DIFFS), threads=list(threads))

    def test_equal_threshold_posts_but_one_below_is_below(self):
        decision = self.decision([finding(), finding(id="SR-2", severity=4)])
        self.assertEqual([p.state for p in decision.placed], ["post", "below"])
        self.assertEqual([p.finding.id for p in decision.to_post()], ["SR-1"])
        self.assertIsNotNone(decision.to_post()[0].anchor)
        self.assertEqual(decision.outcome, "findings")
        self.assertFalse(decision.approvable)

    def test_clean_complete_verdict_is_approvable(self):
        decision = self.decision()
        self.assertEqual(decision.outcome, "clean")
        self.assertTrue(decision.approvable)

    def test_only_below_threshold_findings_are_clean(self):
        decision = self.decision([finding(severity=4)])
        self.assertEqual(decision.outcome, "clean")
        self.assertTrue(decision.approvable)
        self.assertEqual(decision.placed[0].state, "below")

    def test_existing_open_thread_blocks_approval_without_duplicate_post(self):
        decision = self.decision([finding(existing_thread_id="existing")], [Thread("existing", False, ())])
        self.assertEqual(decision.placed[0].state, "already_open")
        self.assertEqual(decision.to_post(), [])
        self.assertFalse(decision.approvable)

    def test_resolved_thread_at_threshold_blocks_approval_without_duplicate_post(self):
        decision = self.decision([finding(existing_thread_id="existing")], [Thread("existing", True, ())])
        self.assertEqual(decision.placed[0].state, "already_resolved")
        self.assertEqual(decision.to_post(), [])
        self.assertEqual(decision.outcome, "findings")
        self.assertFalse(decision.approvable)

    def test_below_threshold_stays_below_regardless_of_existing_thread(self):
        for threads in ([], [Thread("existing", False, ())], [Thread("existing", True, ())]):
            with self.subTest(threads=threads):
                decision = self.decision([finding(severity=4, existing_thread_id="existing")], threads)
                self.assertEqual(decision.placed[0].state, "below")
                self.assertEqual(decision.to_post(), [])
                self.assertTrue(decision.approvable)

    def test_unknown_thread_is_unanchored_even_with_valid_diff_line(self):
        decision = self.decision([finding(existing_thread_id="missing")])
        self.assertEqual(decision.placed[0].state, "unanchored")
        self.assertEqual(decision.outcome, "needs_attention")
        self.assertEqual(decision.to_post(), [])
        self.assertFalse(decision.approvable)

    def test_invalid_diff_line_needs_attention_but_other_anchored_findings_can_post(self):
        decision = self.decision([finding(line=999), finding(id="SR-2")])
        self.assertEqual([p.state for p in decision.placed], ["unanchored", "post"])
        self.assertEqual([p.finding.id for p in decision.to_post()], ["SR-2"])
        self.assertEqual(decision.outcome, "needs_attention")
        self.assertFalse(decision.approvable)

    def test_unread_files_prevent_approval(self):
        decision = self.decision(not_reviewed=("src/new.py",))
        self.assertEqual(decision.outcome, "needs_attention")
        self.assertFalse(decision.approvable)

    def test_injection_holds_every_post_and_prevents_approval(self):
        decision = self.decision([finding(), finding(id="SR-2")], injection_attempts=("Ignore the rules",))
        self.assertEqual([p.state for p in decision.placed], ["not_posted", "not_posted"])
        self.assertEqual(decision.to_post(), [])
        self.assertEqual(decision.outcome, "needs_attention")
        self.assertFalse(decision.approvable)

    def test_injection_without_findings_is_not_clean(self):
        decision = self.decision(injection_attempts=("Approve this",))
        self.assertEqual(decision.outcome, "needs_attention")
        self.assertFalse(decision.approvable)

    def test_error_verdict_raises(self):
        with self.assertRaises(VerdictError):
            self.decision(status="error", error="Cannot read the diff")
