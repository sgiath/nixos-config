# Interface design

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

5. **Keep effects out of pure layers.** When a pure transformation needs something only an effectful layer can supply, such as resolving a module from disk, accept it as a function argument that the layer above provides in production. That argument is a production interface, not test-only injection, and it keeps the pure layer testable with a plain function.

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

