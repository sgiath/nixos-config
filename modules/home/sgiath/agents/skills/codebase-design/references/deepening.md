# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies. Assumes the vocabulary in [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**.

## Dependency categories

When assessing a candidate for deepening, classify its dependencies. The category determines how the deepened module is tested across its seam.

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable — merge the modules and test through the new interface directly. No adapter needed.

### 2. Local-substitutable

Dependencies that have local test stand-ins (PGLite for Postgres, in-memory filesystem). Deepenable if the stand-in exists. The deepened module is tested with the stand-in running in the test suite. The seam is internal; no port at the module's external interface.

### 3. Remote but owned

Your own services across a network seam (microservices, internal APIs). Usually hide the transport behind a named boundary module and call it directly from the deep module. Tests mock that boundary module with Mimic.

Recommendation shape: *"Put the HTTP/gRPC/queue details in `MyApp.InventoryClient`, call that module directly from the deep module, and mock `MyApp.InventoryClient` in tests so the logic stays concentrated behind one interface."*

Use behaviours or injected adapters only when production genuinely selects between multiple implementations, such as region-specific transports or a customer-specific backend.

### 4. True external

Third-party services (Stripe, Twilio, etc.) you don't control. Put the integration behind a boundary module and mock that module with Mimic in tests. Do not introduce a port or injected adapter solely for testing.

## Seam discipline

- **One production adapter means a hypothetical seam. Two production adapters means a real one.** Don't introduce a port unless real production variation justifies it. A test-only fake does not count; use Mimic at the boundary module instead.
- **Internal seams vs external seams.** A deep module can have internal seams (private to its implementation, used by its own tests) as well as the external seam at its interface. Don't expose internal seams through the interface just because tests use them.

## Testing strategy: replace, don't layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist — delete them.
- Write new tests at the deepened module's interface. The **interface is the test surface**.
- Tests assert on observable outcomes through the interface, not internal state.
- Tests should survive internal refactors — they describe behaviour, not implementation. If a test has to change when the implementation changes, it's testing past the interface.
- For external I/O in Elixir, mock the boundary module with Mimic instead of adding dependency injection only for tests.
