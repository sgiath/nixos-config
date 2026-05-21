# Deep Modules

From "A Philosophy of Software Design":

**Deep module** = small interface + lots of implementation

```text
+---------------------+
|   Small Interface   |  <- Few public functions, simple params
+---------------------+
|                     |
|                     |
|  Deep Implementation|  <- Complex logic hidden
|                     |
|                     |
+---------------------+
```

**Shallow module** = large interface + little implementation (avoid)

```text
+---------------------------------+
|       Large Interface           |  <- Many functions, complex params
+---------------------------------+
|  Thin Implementation            |  <- Mostly passes through
+---------------------------------+
```

In Elixir, a deep module usually means a small public API over private helpers, pattern matching, schemas, queries, or process details. Callers should not need to know the internal data shape unless that shape is the public contract.

When designing interfaces, ask:

- Can I reduce the number of public functions?
- Can I accept a domain struct or options keyword list instead of many loose params?
- Can I hide parsing, validation, querying, or process messaging inside the module?
- Can the public function name describe the domain behavior instead of the implementation step?
