# Test Layers

Placing tests is a design decision. Split the system into layers that each make sense on their own, each built
on the one below, and test every layer at its own interface. A behavior gets its test at the lowest layer that
can express it.

## Design layers that can be tested

- **Keep the bottom layer pure.** Data in, data out: no disk, network, processes or clock. Fine-grained
  properties such as preserved source positions, scoping rules and edge cases of a transformation are cheap to
  check there.
- **Put effects in the layer above.** When the pure layer needs something only an effectful layer can supply,
  such as finding a module on disk, it takes a function argument. The layer above passes the real resolver in
  production, so the argument is part of the pure layer's interface, not test plumbing. Tests pass a plain
  function. This differs from injecting a boundary module only to mock it; see [mocking.md](mocking.md).
- **Each layer earns its place.** If a layer exists only so tests have somewhere to attach, merge it.

## Test upward, do not isolate

- A layer's tests run every layer below it for real. Do not mock the layer below to test the one above in
  isolation; that duplicates the lower layer's coverage and couples the test to the calls between them. Mock
  only at system boundaries.
- Aim a middle layer's tests at what that layer adds (resolving modules, interplay between modules), not at
  properties the lower layer already covers.
- For transformations, golden tests catch whole-stack drift cheaply: input fixtures, committed expected outputs
  and a regenerate script. Review regenerated outputs like code; accepting them unread makes the test
  tautological.
- Keep the end-to-end layer thin: a few tests that prove the layers are wired together through the real entry
  point. Do not route fine-grained assertions through it.

```elixir
# BAD: to check that translation keeps line numbers, compile a project, run the
# external prover and read the line back from its diagnostic.
test "translation keeps source lines" do
  {:error, [diagnostic]} = Prover.check(project_with_bug_on_line(9))

  assert diagnostic.line == 9
end

# GOOD: the pure layer takes an AST and returns an AST; assert on it directly.
test "translation keeps source lines" do
  ast = Fixtures.core_ast("sum([X | Xs]) -> X + sum(Xs).", line: 9)

  assert %{anno: %{line: 9}} = Translate.function(ast, fn _remote -> :error end)
end
```

If every test runs through the most expensive layer, the suite grows from seconds to minutes to hours, and
every regression pays that cost.

## Place regressions low

Write a reported bug's failing test at the lowest layer that reproduces it with its real call pattern; a
single-caller test is too low when the failure needs several callers or a longer chain. If only the end-to-end layer can,
either the bug is in the wiring, or the layer that owns the behavior has no usable interface. Treat the second
case as a design finding for skill://codebase-design rather than adding another slow test.

## Keep assertions when moving tests

Moving a test to another layer must not weaken it. Before deleting the old test, map each of its assertions to
one in the replacement: the exact outcome (which record, which error), not just success or failure, plus its
boundary and edge cases. Then show the replacement discriminates: break the behavior with a focused throwaway
mutation and see the new test fail at its intended layer. A replacement that passes against the mutation lost
coverage, even when the whole suite is green.

## State the laws before examples

Types establish the shape of a result, not its value. Before picking examples, write down what the code must
preserve: base cases (`sum([]) == 0`) and laws relating operations (`sum(l) + sum(r) == sum(l ++ r)`). A law
covers classes of bugs that a single example misses, and it relates outputs to each other instead of
recomputing them. Express laws as property tests when the project already has a property-testing library;
otherwise choose a few examples that exercise each law.

## Record the layer map

Correct placement differs per project. Read the project's `AGENTS.md` for its layers and which test files target
each one. When review moves code or a test to a different layer, record the corrected rule in that `AGENTS.md`
as part of the fix, so the next change needs less correction.
