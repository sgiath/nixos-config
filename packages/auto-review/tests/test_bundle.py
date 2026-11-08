import json
import tempfile
import unittest
from pathlib import Path

from auto_review import bundle
from auto_review.models import Note, Thread
from tests.fakes import change

CODERABBIT = """Add the restriction from `implementation.md`.

<!-- ai-agent-prompt:start -->

<details>
<summary>Prompt for AI Agents</summary>

```
Verify each finding against current code. Fix only still-valid issues.
```

</details>

<!-- ai-agent-prompt:end -->

<!-- This is an auto-generated reply by CodeRabbit -->"""


class BundleTest(unittest.TestCase):
    def test_discussions_drop_prompts_other_bots_address_to_coding_agents(self):
        thread = Thread("t1", False, (Note("coderabbitai", CODERABBIT, "n1"),), "docs/plan.md", 16)
        with tempfile.TemporaryDirectory() as tmp:
            run_dir = Path(tmp)
            bundle.write(run_dir, change(), [], [thread])
            body = json.loads((run_dir / "mr/discussions.json").read_text())[0]["notes"][0]["body"]
        self.assertIn("Add the restriction from `implementation.md`.", body)
        self.assertIn("auto-generated reply by CodeRabbit", body)
        self.assertNotIn("Prompt for AI Agents", body)
        self.assertNotIn("Fix only still-valid issues", body)
