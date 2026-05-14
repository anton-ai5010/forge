# DDD-Aware Testing

If the design doc has a Domain Model, prioritize these test categories:

1. **Domain Primitives** — test that invalid values are rejected at creation:
   - `new Email("bad")` throws
   - `new Money(-1, "USD")` throws

2. **Entity Lifecycle** — test every state transition:
   - `order.pay()` works from "draft"
   - `order.pay()` throws from "delivered"

3. **Aggregate Invariants** — test that the root entity maintains consistency:
   - `order.addItem()` updates total
   - `order.removeItem()` when empty throws

4. **Boundary Rules** — test that aggregates communicate only by ID, not by sharing internal objects.

These tests catch the hardest bugs — the ones where data is technically valid but logically wrong.
