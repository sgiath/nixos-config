# Refactor Candidates

After TDD cycle, look for:

- **Duplication** -> Extract a function, module, or test helper
- **Long functions** -> Break into private helpers while keeping tests on the public interface
- **Shallow modules** -> Combine thin pass-through modules or deepen the public boundary
- **Feature envy** -> Move logic to the module that owns the domain concept
- **Primitive obsession** -> Introduce structs, embedded schemas, tagged tuples, or domain-specific types
- **Unclear result handling** -> Normalize to `{:ok, value}` / `{:error, reason}` where callers need to branch
- **Process misuse** -> Keep GenServer state transitions small and push pure domain logic into ordinary modules
- **Existing code** the new code reveals as problematic
