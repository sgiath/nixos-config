# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```elixir
test "customer can checkout with a valid cart" do
  customer = customer_fixture()
  product = product_fixture(price: Money.new(:USD, "12.00"))
  cart = Shopping.add_to_cart(customer, product, quantity: 1)

  assert {:ok, receipt} = Checkout.complete(cart, payment_method_fixture())
  assert receipt.status == :confirmed
end
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One behavior per test; multiple assertions are fine when they describe the same observable outcome

In Phoenix or Ecto code, prefer the highest useful public boundary:

- Context functions for domain behavior
- LiveView or controller tests for user-facing flows
- Sandboxed Repo only as part of exercising the real public path

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```elixir
# BAD: tests an internal call instead of checkout behavior.
test "checkout calls the payment service" do
  expect(MyApp.MockPaymentService, :process, fn amount ->
    assert amount == Money.new(:USD, "12.00")
    {:ok, %{id: "pay_123"}}
  end)

  Checkout.complete(cart_fixture(), payment_method_fixture())
end
```

Red flags:

- Mocking internal modules
- Testing private functions through indirection
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```elixir
# BAD: bypasses the public interface to verify persistence.
test "create_user inserts a row" do
  assert {:ok, _user} = Accounts.create_user(%{name: "Alice"})

  assert Repo.exists?(
           from u in User,
             where: u.name == "Alice"
         )
end

# GOOD: verifies through another public interface.
test "created user can be fetched by id" do
  assert {:ok, user} = Accounts.create_user(%{name: "Alice"})

  assert {:ok, fetched} = Accounts.fetch_user(user.id)
  assert fetched.name == "Alice"
end
```

For LiveView, test user-visible behavior instead of assigned implementation details:

```elixir
# BAD: asserts on internal assigns.
test "filters stores selected status in assigns", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/orders")

  view
  |> element("button", "Paid")
  |> render_click()

  assert :paid == :sys.get_state(view.pid).socket.assigns.status
end

# GOOD: asserts on observable UI.
test "filters orders by payment status", %{conn: conn} do
  paid_order = order_fixture(status: :paid)
  _draft_order = order_fixture(status: :draft)

  {:ok, view, _html} = live(conn, ~p"/orders")

  html =
    view
    |> element("button", "Paid")
    |> render_click()

  assert html =~ paid_order.number
  refute html =~ "Draft"
end
```
