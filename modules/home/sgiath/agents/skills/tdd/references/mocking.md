# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock with
[Mimic](https://mimic.hexdocs.pm/readme.html):

```elixir
# mix.exs
def deps do
  [
    {:mimic, "~> 2.0", only: :test}
  ]
end
```

Prepare only boundary modules in `test/test_helper.exs`:

```elixir
Mimic.copy(MyApp.PaymentClient)
Mimic.copy(MyApp.EmailClient)
Mimic.copy(MyApp.BillingAPI)

ExUnit.start()
```

**1. Mock boundary modules directly**

With Mimic, you do not need to pass modules around just to make tests
mockable. Keep production code simple: call the boundary module directly, then
mock that module in the test.

```elixir
defmodule MyApp.Payments do
  # Clean production code: no test-only dependency plumbing.
  def process_payment(order) do
    MyApp.PaymentClient.charge(order.total)
  end
end
```

Mock the boundary module in the test, not the code under test:

```elixir
defmodule MyApp.PaymentsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias MyApp.Payments

  test "charges the payment provider" do
    order = %{total: 5000}

    MyApp.PaymentClient
    |> expect(:charge, fn 5000 -> {:ok, %{id: "ch_123"}} end)

    assert {:ok, %{id: "ch_123"}} = Payments.process_payment(order)
  end
end
```

Avoid dependency injection when it exists only for tests:

```elixir
defmodule MyApp.Payments do
  # Avoid: this makes callers care about a dependency they should not own.
  def process_payment(order, payment_client \\ MyApp.PaymentClient) do
    payment_client.charge(order.total)
  end
end
```

Use dependency injection only when production behavior genuinely needs runtime
selection of different implementations.

**2. Prefer SDK-style interfaces over generic request functions**

Create specific functions for each external operation instead of one generic
function with conditional logic:

```elixir
# GOOD: Each function is independently mockable.
defmodule MyApp.BillingAPI do
  def get_customer(id), do: Req.get!("/customers/#{id}")
  def list_invoices(customer_id) do
    Req.get!("/customers/#{customer_id}/invoices")
  end

  def create_invoice(attrs), do: Req.post!("/invoices", json: attrs)
end

# BAD: Mocking requires conditional logic inside the mock.
defmodule MyApp.BillingAPI do
  def request(method, path, opts \\ []) do
    Req.request!([method: method, url: path] ++ opts)
  end
end
```

With the SDK-style module, tests stay direct:

```elixir
test "creates an invoice for the customer" do
  MyApp.BillingAPI
  |> expect(:get_customer, fn "cus_123" -> {:ok, %{id: "cus_123"}} end)
  |> expect(:create_invoice, fn %{customer_id: "cus_123", amount: 5000} ->
    {:ok, %{id: "inv_123"}}
  end)

  assert {:ok, %{id: "inv_123"}} = MyApp.Billing.create_invoice("cus_123", 5000)
end
```

The SDK approach means:
- Each mock returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Expectations verify calls at test end when using `use Mimic`
