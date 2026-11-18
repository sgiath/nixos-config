import json
import tomllib
import unittest

import toml_json


def merge(original, change):
    """What the activation does: TOML -> JSON, `change`, JSON -> TOML."""
    new = change(json.loads(toml_json.to_json(original)))
    return toml_json.from_json(original, new), new


class FromJsonTest(unittest.TestCase):
    def test_keeps_comments_and_formatting_of_untouched_values(self):
        original = '# keep\n[models]\ndefault = "a" # picked\nallowed = ["x"]\n\n[ui]\ntheme = "dark"\n'

        def change(d):
            d["models"]["allowed"] = ["y"]
            return d

        text, new = merge(original, change)
        self.assertEqual(text, original.replace('["x"]', '["y"]'))
        self.assertEqual(tomllib.loads(text), new)

    def test_unchanged_file_is_byte_identical(self):
        original = 'b = true # c\r\nf = 1.5\r\n[t]\r\nx = [1, 2]\r\n'
        self.assertEqual(merge(original, lambda d: d)[0], original)

    def test_dotted_keys_read_back_as_the_merged_values(self):
        original = 'model.local.name = "local"\nmodel.local.model = "native"\n'

        def change(d):
            d["model"]["gpt"] = {"name": "G"}
            return d

        text, new = merge(original, change)
        self.assertEqual(tomllib.loads(text), new)

    def test_replaces_a_value_whose_type_changed(self):
        text, _ = merge("a = 1\nb = [1]\n", lambda d: {"a": True, "b": [1.0]})
        self.assertEqual(json.dumps(tomllib.loads(text), sort_keys=True), '{"a": true, "b": [1.0]}')

    def test_refuses_dates(self):
        with self.assertRaises(SystemExit):
            toml_json.to_json("a = 2026-01-01\n")


if __name__ == "__main__":
    unittest.main()
