# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer sandboxed test DB)
- Time/randomness
- File system (sometimes)
- Background queues or remote services

Don't mock:

- Your own modules
- Internal collaborators
- Ecto changesets or query builders you control
- Anything that can run cheaply and deterministically in-process

## Designing for Mockability

At system boundaries, design interfaces that are easy to replace in tests:

**1. Inject boundary modules or functions**

Pass external dependencies in rather than hard-coding them internally:

```elixir
# Easy to test with a fake module.
def process_payment(order, payment_client \\ MyApp.Payments.Stripe) do
  payment_client.charge(order.total)
end

# Hard to test without patching global configuration or using a mocking library.
def process_payment(order) do
  client = MyApp.Payments.Stripe.new(System.fetch_env!("STRIPE_KEY"))
  client.charge(order.total)
end
```

For application code, dependency injection can be simple: a default module argument, an MFA tuple, or a behaviour-backed module from config. Avoid pushing mocks through every internal function just because you can.

**2. Prefer boundary-specific APIs over generic request functions**

Create specific functions for each external operation instead of one generic function with conditional logic:

```elixir
# GOOD: each function has one purpose and one return shape.
defmodule MyApp.BillingGateway do
  @callback get_customer(String.t()) :: {:ok, customer()} | {:error, term()}
  @callback list_invoices(String.t()) :: {:ok, [invoice()]} | {:error, term()}
  @callback create_invoice(map()) :: {:ok, invoice()} | {:error, term()}
end

# BAD: tests need conditional fake logic for method, path, and body.
defmodule MyApp.BillingGateway do
  @callback request(method :: atom(), path :: String.t(), body :: map()) ::
              {:ok, map()} | {:error, term()}
end
```

The boundary-specific approach means:

- Each fake returns one specific shape
- No conditional logic in test setup
- Easier to see which external capability a test exercises
- Dialyzer specs and behaviours describe the contract per operation
