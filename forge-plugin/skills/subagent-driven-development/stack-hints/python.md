# Python Stack Hints

Inject into implementer prompt when `.forge/conventions.yml` has `language: python`.

## Idiomatic Patterns

- Use `dataclasses` or `Pydantic BaseModel` for data structures, not plain dicts
- Type hints on all public functions (`def process(data: list[Order]) -> Result:`)
- `Protocol` for duck typing interfaces, not ABC unless you need shared implementation
- Context managers (`with`) for any resource that needs cleanup
- `pathlib.Path` over `os.path`
- f-strings over `.format()` or `%`
- List/dict comprehensions over `map`/`filter` when readable
- `enum.Enum` for fixed sets of values, not string constants

## Async

- `async def` + `await` for I/O-bound work (HTTP, DB, files)
- `asyncio.gather()` for concurrent I/O, not sequential awaits
- Never mix `requests` (sync) with async code — use `httpx` or `aiohttp`
- `async with` for async context managers (DB connections, HTTP sessions)

## Error Handling

- Custom exceptions inheriting from a project base exception
- Never bare `except:` — always `except SpecificError`
- Use `raise ... from e` to preserve exception chain
- `logging.exception()` in catch blocks, not `print(traceback)`

## Testing

- `pytest` (not unittest) — fixtures, parametrize, tmp_path
- `pytest.fixture` for setup/teardown, scope appropriately (function/module/session)
- `@pytest.mark.parametrize` for multiple test cases
- `pytest.raises(SpecificError)` for error testing
- Mock external services with `unittest.mock.patch` or `respx`/`pytest-httpx`
- `conftest.py` for shared fixtures

## Project Structure

```
src/{package}/         # or just {package}/ at root
  __init__.py
  models.py            # Pydantic/dataclass models
  services.py          # Business logic
  exceptions.py        # Custom exceptions
tests/
  conftest.py          # Shared fixtures
  test_{module}.py     # Mirror src structure
pyproject.toml         # Not setup.py
```

## Performance

- `functools.lru_cache` / `@cache` for pure function memoization
- Generator expressions for large datasets (`sum(x for x in items)`)
- `__slots__` on high-frequency classes
- Profile before optimizing: `cProfile`, `line_profiler`

## Security

- `secrets.token_urlsafe()` for tokens, not `random`
- `hashlib.pbkdf2_hmac` or `bcrypt` for passwords
- Pydantic validation for all external input
- `subprocess.run([...])` with list args, never `shell=True` with user input
