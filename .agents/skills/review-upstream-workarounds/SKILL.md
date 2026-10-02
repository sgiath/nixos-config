---
name: review-upstream-workarounds
description: Manually invoked audit of every active record in UPSTREAM-WORKAROUNDS.md against live upstream and the sources this flake actually selects. Run only via /skill:review-upstream-workarounds.
disable-model-invocation: true
---

# Review upstream workarounds

Manual audit only. It never runs automatically at session start or on its own.

## Setup

- Repository root is `../../../` from this skill's directory. Run commands there.
- Read the root `UPSTREAM-WORKAROUNDS.md`. It is the only inventory. Do not copy records into this skill, notes, or comments.
- Use its read-only commands, removal gates, validation profiles, and status values. Do not invent new ones.

## Review every active record

1. **Resolve what is selected.** Resolve root and nested input pins (for example Hyprland's or ComfyUI's nixpkgs) through `flake.inputs` with the registry's pin commands. Resolve each record's selected package, version, or fetched source through the full `nixosConfigurations.<host>`. Never read bare `flake.lock` nodes such as `nodes.nixpkgs`, and never evaluate Home Manager outputs on their own.
2. **Check every active record**, however recent its last check. A date is not a waiver.
3. **Compare live upstream with the selected source.** A merged PR, closed issue, newer release, or fix on `main` alone is not proof. Confirm the fix is in the exact pinned revision or fetched source (`compare` the fix commit against the pin, or read the file at the pin).
4. **Unknown is not removable.** If a check fails (offline, API error, missing credentials), keep the workaround, set status `unknown`, record the failed check, and continue with the remaining records.
5. **Deliberate choices stay.** Leave deliberate groups and product decisions alone unless the user explicitly asks to revisit one. Do not report them as stale.
6. **Update the registry.** When a record's material evidence or status changes, update its detailed record (status, evidence, date) and its row in the active status table so the two agree. Refresh the shared baseline and pin line only with values you actually resolved in this run. Do not redate unchanged historical evidence. The registry is the only file the audit itself edits.

## Security records

Delegate security-exception records and any credential- or secret-handling question to a subagent using model `openai-codex/gpt-daybreak-blue-latest`. Give it the record, its pins, and these rules. Never print or commit secrets, and never reset production state.

## Report

Give the user, with source evidence (URL plus pinned rev or compare result) for each:

- kept (`required`, `dormant`, `decision`, `unverified`) and anything whose status changed
- removal candidates and the gate each one meets
- `unknown` records with the failed check
- `expired` deadlines, and `watch` deadlines that are past or within 30 days

## Removal boundary

This audit does not authorize removing source, upgrading inputs, building packages or full systems, or deploying. Remove a workaround only when the task explicitly allows it **and** all of the following hold:

- the record's removal gate is met against the selected source
- obsolete callers, patches, forks, and workaround comments are deleted in the same change (clean cutover)
- every full NixOS system in the record's profile is built from the registry validation commands; Home Manager alone never counts
- the required runtime behavior is actually exercised
- the record moves to Resolved history in the same change

If runtime proof is not available, the record stays `candidate` and the report names the missing proof.
