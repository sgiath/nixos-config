---
name: tdd
description: "Use when implementing bug fixes or new behavior with test-first verification, or when asked for a red-green-refactor workflow."
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Consult the linked examples when choosing assertions or mocking boundaries.

skill://verified-work owns the task's gates, handoffs and blocker decisions; this skill owns behavioral test design
and implementation cycles. A diagnostic harness or benchmark need not become a committed unit test. For instruction
edits and scratch tooling, use appropriate validation instead of adding tests that only prove wording was changed.

When exploring the codebase, read `CONTEXT.md` (if it exists) so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists — and survives refactors because it doesn't care about internal structure.

See [tests.md](references/tests.md) for examples and [mocking.md](references/mocking.md) for mocking guidelines.

## Seams — where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

Use the seams established by the task and existing tests. If the user requested seam approval, obtain it before
writing tests; otherwise identify the observable behavior and proceed. Ask when seam selection would settle an
unresolved product/interface decision, or when a required behavioral check cannot be established or met under
verified-work's blocker rule. Do not stop just because a faithful harness has no existing unit-test seam.

In a layered system, test each behavior at the lowest layer that can express it, let a layer's tests run the
layers below it for real, and keep the end-to-end layer thin. [layers.md](references/layers.md) covers designing
testable layers, golden tests, regression placement and stating laws before examples.

When the shape of that interface is itself in question — how deep the module is, where the seam belongs, what the interface should expose — use the `/codebase-design` skill for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is a reference to consult, not a session to run.

## Anti-patterns

- **Implementation-coupled** — mocks internal collaborators, tests private methods, or verifies through a side channel when the contract has an observable public read path. Querying persisted state is appropriate when persistence or transaction behavior is itself the contract under test. The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological** — the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth — a known-good literal, a worked example, the spec.
- **Wrong layer** — a fine-grained property asserted through the expensive end-to-end path, or a layer tested with the layer below it mocked out. The tell: a precise assertion needs a slow, indirect setup, or the test duplicates coverage the lower layer already has.
- **Horizontal slicing** — writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead — one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **Red means the unchanged baseline.** The red run is the new test failing against the code before this cycle's
  implementation, on its own assertion (not a compile error, empty output or a setup failure). Record the
  revision, the failing assertion and the failure count. Mutating code after it is written is a separate
  sensitivity check: useful, but report it as a mutation, never as the red run.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactor with green tests.** Simplify when the completed slice exposes a concrete problem, then rerun the affected tests. See [refactoring candidates](references/refactoring.md); do not turn the list into a mandatory sweep.

Planning several gates does not mean writing every test up front. Complete one behavioral cycle at a time, then
run the task's integration gates. Keep scratch reproduction checks throwaway by default; commit focused tests
only when they exercise production code and preserve a meaningful guarantee.
