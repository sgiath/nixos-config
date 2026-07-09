---
name: codebase-design
description: Shared vocabulary for designing deep modules. Use when the user wants to design or improve a module's interface, find deepening opportunities, decide where a seam goes, make code more testable or AI-navigable, or when another skill needs the deep-module vocabulary.
---

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface. Use this language and these principles wherever code is being designed or restructured. The aim is leverage for callers, locality for maintainers, and testability for everyone.

## Glossary

Use these terms exactly — don't substitute "component," "service," "API," or "boundary." Consistent language is the whole point.

**Module** — anything with an interface and an implementation. Deliberately scale-agnostic: a function, Elixir module, package, process, or tier-spanning slice. _Avoid_: unit, component, service.

**Interface** — everything a caller must know to use the module correctly: the type signature, but also invariants, ordering constraints, error modes, required configuration, and performance characteristics. _Avoid_: API, signature (too narrow — they refer only to the type-level surface).

**Implementation** — what's inside a module, its body of code. Distinct from **Adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in-memory fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.

**Depth** — leverage at the interface: the amount of behaviour a caller (or test) can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface, **shallow** when the interface is nearly as complex as the implementation.

**Seam** _(Michael Feathers)_ — a place where you can alter behaviour without editing in that place; the *location* at which a module's interface lives. Where to put the seam is its own design decision, distinct from what goes behind it. _Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter** — a concrete thing that satisfies an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside).

**Leverage** — what callers get from depth: more capability per unit of interface they learn. One implementation pays back across N call sites and M tests.

**Locality** — what maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place rather than spreading across callers. Fix once, fixed everywhere.

## Deep vs shallow

**Deep module** = small interface + lots of implementation:

```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid):

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

When designing an interface, ask:

- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small parts — they just aren't part of the interface. A module can have **internal seams** private to its implementation, but don't expose them through the caller-facing interface just for tests.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.
- **One production adapter means a hypothetical seam. Two production adapters means a real one.** Don't introduce a seam unless production behaviour actually varies across it. A test-only fake does not justify widening the interface.

## Designing for testability

Good interfaces make testing natural:

1. **Mock boundary modules directly.**

   With Mimic, production code can call external boundary modules directly. Do not pass modules around only to make tests mockable.

   ```elixir
   defmodule MyApp.Orders do
     def process_order(order) do
       with {:ok, charge} <- MyApp.PaymentGateway.charge(order.total) do
         {:ok, Map.put(order, :charge_id, charge.id)}
       end
     end
   end
   ```

   ```elixir
   test "charges the payment gateway" do
     MyApp.PaymentGateway
     |> expect(:charge, fn 5000 -> {:ok, %{id: "ch_123"}} end)

     assert {:ok, %{charge_id: "ch_123"}} = Orders.process_order(%{total: 5000})
   end
   ```

2. **Return results, don't produce side effects.**

   Prefer values that callers can assert on. Use explicit success/error results for operations that can fail.

   ```elixir
   # Easy to test
   def calculate_discount(cart), do: {:ok, %Discount{amount: 1_000}}

   # Harder to test: observable only through hidden mutation or I/O
   def apply_discount(cart), do: CartStore.update_total(cart.id, -1_000)
   ```

3. **Small surface area.** Fewer methods = fewer tests needed. Fewer params = simpler test setup.

4. **Use adapters only for real production variation.** Elixir behaviours and injected modules are useful when production has multiple implementations. A test-only fake is not enough reason to widen the interface.

## Relationships

- A **Module** has exactly one **Interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.

## Rejected framings

- **Depth as ratio of implementation-lines to interface-lines** (Ousterhout): rewards padding the implementation. We use depth-as-leverage instead.
- **"Interface" as only an Elixir behaviour callback list or a module's public functions**: too narrow — interface here includes every fact a caller must know.
- **"Boundary"**: overloaded with DDD's bounded context. Say **seam** or **interface**.

## Going deeper

- **Deepening a cluster given its dependencies** — see [deepening.md](./reference/deepening.md): dependency categories, seam discipline, and replace-don't-layer testing.
- **Exploring alternative interfaces** — see [design-it-twice.md](./reference/design-it-twice.md): spin up parallel sub-agents to design the interface several radically different ways, then compare on depth, locality, and seam placement.
