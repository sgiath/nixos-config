---
description: Structured scientific debugging workflow
---

# Debug: $ARGUMENTS

When `$ARGUMENTS` is empty, infer what to debug from the current conversation context - look for:
- Recent errors or unexpected behavior discussed
- Failed tests or commands
- User frustration with something not working

If nothing obvious, ask: "What issue should I debug?"

## Prerequisites Check

Determine reproduction method:
- **Unit test provided?** → Run automatically
- **Command to trigger?** → Run automatically  
- **Neither?** → Will need user to manually reproduce

## Step 1: Explore Relevant Code

- Read code related to the issue
- Trace execution path from entry to problem
- Note key functions, conditionals, error handling
- Identify data transformations involved

## Step 2: Form 3-5 Hypotheses

Each hypothesis must be:
- Specific and testable
- Identify concrete code location
- Explain what's wrong, expected vs actual
- Distinct from others

Format:
```
## Hypotheses

1. **[Location: module/function]** Issue caused by X because Y
2. **[Location: module/function]** Data transformation at Z incorrect when W
3. **[Location: module/function]** Condition check for A fails when B
```

## Step 3: Add Debug Instrumentation

**CRITICAL**: Do NOT use standard logging. Write JSON to `debug.log` in project root.

### Elixir Pattern
```elixir
defp debug_log(hypothesis, label, data) do
  entry = %{
    timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
    hypothesis: hypothesis,
    label: label,
    data: data,
    module: __MODULE__,
    function: __ENV__.function |> elem(0),
    line: __ENV__.line
  }
  File.write!("debug.log", JSON.encode!(entry) <> "\n", [:append])
end

# Usage:
debug_log(1, "input_params", %{user_id: user_id, filters: filters})
```

### TypeScript/JavaScript Pattern
```typescript
const debugLog = (hypothesis: number, label: string, data: unknown) => {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    hypothesis,
    label,
    data,
    file: import.meta.url,
  });
  require('fs').appendFileSync('debug.log', entry + '\n');
};
```

### Python Pattern
```python
import json
from datetime import datetime

def debug_log(hypothesis: int, label: str, data):
    entry = json.dumps({
        "timestamp": datetime.utcnow().isoformat(),
        "hypothesis": hypothesis,
        "label": label,
        "data": data,
    })
    with open("debug.log", "a") as f:
        f.write(entry + "\n")
```

Log at strategic points:
- Function entry/exit with params and return values
- Before/after conditional branches
- Data transformation inputs/outputs
- Loop iterations with index and values
- Error handling paths

## Step 4: Trigger the Bug

**If test/command available:** Run it automatically
**If manual:** Ask user to reproduce, wait for confirmation

## Step 5: Analyze Debug Log

Read `debug.log` and determine for each hypothesis:
- **CONFIRMED** - Log shows this IS the problem
- **DISPROVED** - Log shows this is NOT the problem
- **INCONCLUSIVE** - Need more data

Format:
```
## Hypothesis Analysis

1. **DISPROVED** - Input params correct: {data}
2. **CONFIRMED** - Query returned empty when should have data: {data}
3. **DISPROVED** - Condition check passed: {data}

**Root Cause:** Hypothesis #2 - [explanation]
```

**If all disproved/inconclusive:** Return to Step 1 with new understanding, form new hypotheses.

## Step 6: Fix the Bug

- Make minimal fix
- Keep instrumentation (don't remove yet)
- Explain what you're fixing and why

## Step 7: Verify the Fix

```bash
echo "" > debug.log  # Clear log
```

Re-run test/command or ask user to reproduce again.

## Step 8: Confirm and Clean Up

Read debug.log one final time to verify:
- Fix working as expected
- No unexpected side effects

**If FIXED:**
- Remove ALL debug instrumentation
- Delete `debug.log`
- Report success

**If NOT FIXED:**
- Keep instrumentation
- Return to Step 1 with new info

## Rules

- **NEVER** skip hypothesis step
- **NEVER** use standard logging - pollutes logs, may miss data
- **ALWAYS** use JSON format in debug.log
- **ALWAYS** clean up after debugging complete
- **ALWAYS** dump more data than needed - filter later
- **TAG** each log with hypothesis number
- **BE SYSTEMATIC** - don't jump randomly
