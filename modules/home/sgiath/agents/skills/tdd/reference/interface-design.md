# Interface Design for Testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them**

   ```elixir
   # Testable: callers can pass a fake boundary module.
   def checkout(cart, payment_gateway \\ MyApp.Payments.Stripe) do
     payment_gateway.charge(cart.total)
   end

   # Hard to test: the external boundary is fixed inside the function.
   def checkout(cart) do
     MyApp.Payments.Stripe.charge(cart.total)
   end
   ```

   Prefer injecting modules or functions at system boundaries. For app internals, keep the real module path and test through the public behavior.

2. **Return results, don't mutate hidden state**

   ```elixir
   # Testable: pure calculation with an explicit result.
   def calculate_discount(cart), do: {:ok, %Discount{amount: discount_for(cart)}}

   # Hard to test: the important effect is hidden behind persistence.
   def apply_discount(cart) do
     Repo.update_all(from(i in Item, where: i.cart_id == ^cart.id), inc: [discount: 10])
   end
   ```

   Elixir data is immutable, so lean into return values. When persistence or processes are required, put them behind a public command/query pair that describes the domain behavior.

3. **Use domain-shaped inputs and outputs**

   ```elixir
   # Good: the interface speaks in domain terms.
   def reserve_inventory(%Order{} = order), do: ...

   # Brittle: callers must know unrelated implementation details.
   def reserve_inventory(user_id, sku, quantity, warehouse_id, retry_count), do: ...
   ```

4. **Small surface area**

   - Fewer public functions = fewer behavior contracts to test
   - Fewer loose params = simpler setup and clearer pattern matching
   - Explicit `{:ok, value}` / `{:error, reason}` results = straightforward assertions
