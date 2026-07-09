# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```elixir
# GOOD: Tests observable behavior
test "user can checkout with valid cart" do
  cart =
    Cart.new()
    |> Cart.add(product)

  assert {:ok, %{status: :confirmed}} = Checkout.checkout(cart, payment_method)
end
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```elixir
# BAD: Tests implementation details
test "checkout calls PaymentService.process/1" do
  cart_total = Cart.total(cart)

  PaymentServiceMock
  |> expect(:process, fn ^cart_total -> {:ok, %{id: "pay_123"}} end)

  assert {:ok, _order} = Checkout.checkout(cart, payment_method)
end
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```elixir
# BAD: Bypasses interface to verify
test "create_user saves to database" do
  {:ok, _user} = Accounts.create_user(%{name: "Alice"})

  assert %User{} = Repo.get_by(User, name: "Alice")
end

# GOOD: Verifies through interface
test "create_user makes user retrievable" do
  {:ok, user} = Accounts.create_user(%{name: "Alice"})
  retrieved = Accounts.get_user!(user.id)

  assert retrieved.name == "Alice"
end
```

**Tautological tests**: Expected value restates the implementation, so the test passes by construction.

```elixir
# BAD: Expected value is recomputed the way the code computes it
test "calculate_total sums line items" do
  items = [%{price: 10}, %{price: 5}]
  expected = Enum.reduce(items, 0, fn item, sum -> sum + item.price end)

  assert Cart.calculate_total(items) == expected
end

# GOOD: Expected value is an independent, known literal
test "calculate_total sums line items" do
  assert Cart.calculate_total([%{price: 10}, %{price: 5}]) == 15
end
```
