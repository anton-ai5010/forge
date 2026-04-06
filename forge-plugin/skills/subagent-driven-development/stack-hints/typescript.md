# TypeScript Stack Hints

Inject when `.forge/conventions.yml` has `language: typescript` or framework includes Node.js/Express/Fastify.

## Strict Config

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true
  }
}
```

Never `any`. Use `unknown` + type guards when type is truly unknown.

## Idiomatic Patterns

- Discriminated unions over class hierarchies:
  ```typescript
  type Result = { ok: true; data: T } | { ok: false; error: Error }
  ```
- `satisfies` operator for type checking without widening
- `as const` for literal types
- Branded types for domain primitives: `type UserId = string & { __brand: 'UserId' }`
- `Record<string, T>` over `{ [key: string]: T }`
- `Pick<T, K>` / `Omit<T, K>` for type narrowing
- Nullish coalescing `??` and optional chaining `?.` over `||` and `&&`

## Error Handling

- Custom error classes extending `Error` with `cause` property
- `Result<T, E>` pattern for expected failures (don't throw for business logic)
- Zod or Valibot for runtime validation of external data
- Never `try/catch` around everything — catch specific, let unexpected errors propagate

## Testing

- Vitest (fast) or Jest — prefer Vitest for new projects
- `describe`/`it` blocks with clear behavior names
- `vi.fn()` / `jest.fn()` for mocks — avoid over-mocking
- `supertest` for HTTP endpoint testing
- `@testing-library/*` for UI component testing

## Async

- Always `await` promises — never fire-and-forget
- `Promise.all()` for parallel, `Promise.allSettled()` when partial failure OK
- AbortController for cancellation
- Error handling: `.catch()` on every promise chain or `try/await/catch`

## Project Structure

```
src/
  routes/     # or controllers/
  services/   # Business logic
  models/     # Types and schemas
  utils/      # Pure helpers
  middleware/ # Express/Fastify middleware
tests/
  *.test.ts   # Co-located or mirror src/
```

## Performance

- Avoid N+1 queries — batch with `DataLoader` or `IN` clauses
- Stream large responses: `ReadableStream` / Node.js `stream.pipeline`
- Use `Map` over plain objects for frequent lookups
- Lazy imports: `const mod = await import('./heavy')` for cold-start optimization
