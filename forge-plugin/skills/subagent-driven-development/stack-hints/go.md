# Go Stack Hints

Inject when `.forge/conventions.yml` has `language: go`.

## Idiomatic Patterns

- Accept interfaces, return structs
- Error values, not exceptions: `func Do() (Result, error)`
- `if err != nil { return ..., fmt.Errorf("context: %w", err) }` — always wrap with `%w`
- Small interfaces (1-3 methods) defined by the consumer, not the provider
- `context.Context` as first parameter for anything cancellable/with-deadline
- Table-driven tests for multiple cases
- `defer` for cleanup immediately after resource acquisition

## Error Handling

- Wrap errors: `fmt.Errorf("reading config: %w", err)` — creates trace
- Check with `errors.Is()` and `errors.As()`, not string comparison
- Sentinel errors as `var ErrNotFound = errors.New("not found")`
- Custom error types implement `Error() string` interface
- Never ignore errors: `_ = dangerous()` is a bug

## Concurrency

- Goroutines + channels for communication, not shared memory
- `sync.WaitGroup` for "wait for N goroutines"
- `errgroup.Group` for goroutines that can fail (returns first error)
- `sync.Mutex` only when channels don't fit (protect shared state)
- `context.WithCancel` / `WithTimeout` for goroutine lifecycle
- Never start goroutine without knowing how it stops

## Testing

- `testing` package + `testify/assert` (or `testify/require` for fatal)
- Table-driven: `tests := []struct{ name string; input X; want Y }{...}`
- `t.Parallel()` for independent tests
- `t.Helper()` in test helpers for better error reporting
- `httptest.NewServer` for HTTP testing
- `t.TempDir()` for temp files (auto-cleaned)
- Build tags: `//go:build integration` for slow tests

## Project Structure

```
cmd/app/          # Entry point (main.go)
internal/         # Private code
  handler/        # HTTP/gRPC handlers
  service/        # Business logic
  repository/     # Data access
  model/          # Domain types
pkg/              # Public library code (if any)
```

## Performance

- Pre-allocate slices: `make([]T, 0, expectedLen)`
- `strings.Builder` for string concatenation, not `+=`
- `sync.Pool` for frequently allocated objects
- `pprof` for profiling: `go tool pprof http://localhost:6060/debug/pprof/profile`
- Benchmark with `func BenchmarkX(b *testing.B) { for i := 0; i < b.N; i++ { ... } }`
