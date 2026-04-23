# AI Test Generation Guide — Python

Authoritative reference for the 7-phase test generation pipeline used by `/bestest generate` for Python projects. This guide defines quality standards, scoring rubrics, and design patterns that every generated pytest test must satisfy. The Python generation spoke (`references/spoke-generate-python.md`) consumes this guide during Phase 3 (strategy selection) and Phase 7 (quality audit).

**Scope:** Python projects using pytest (primary), with notes for unittest migration scenarios. All examples use pytest-first syntax with standard fixtures and markers.

**Audience:** AI agents generating tests. This is not a human-facing tutorial — it is a machine-consumable specification for producing high-quality pytest test suites.

---

## Phase 1: Code Analysis

Before writing any test, analyze the target source file across five dimensions. Each dimension determines a different aspect of the test strategy.

### Exports

Identify every function, class, method, and module-level variable. Each public symbol is a testable unit. Classify by type:

| Symbol Type | Test Priority | Analysis Focus |
|-------------|---------------|----------------|
| Function (def) | High | Input/output contract, edge cases, exceptions |
| Async function (async def) | High | Same as function + asyncio patterns |
| Class | High | Constructor, public methods, lifecycle, properties |
| Dataclass / Pydantic model | Medium | Validation, serialization, defaults |
| Constant | Low | Value correctness |
| Private (_ prefix) | Low | Test indirectly via public API |
| __init__.py exports | None | Re-export only; covered by source module tests |

**Decision rule:** If a symbol has runtime behavior (functions, classes, methods), it needs tests. If it is purely declarative (type aliases, constants), skip it. Private symbols (_) are tested indirectly through their public callers unless they contain complex logic warranting direct testing.

### Type Signatures

Extract the type signature for every function and method. The type signature defines the input space and output contract:

```python
# Source
def parse_config(raw: str, defaults: dict[str, Any] | None = None) -> Config: ...

# Analysis
# - Input space: any string + optional dict override
# - Output contract: Config object (shape known from class/type)
# - Edge cases: empty string, malformed input, missing optional fields
# - Raises: likely raises on invalid input (verify from source)
```

When type hints are absent, infer them from docstrings, default values, and usage patterns. Python's dynamic nature makes this inference critical — always verify the inferred types against the actual source logic.

### Dependencies

Map every import to determine what needs mocking:

1. **Pure logic imports** (utility functions, constants) — No mock needed; test with real implementation.
2. **Side-effect imports** (database clients, HTTP libraries, filesystem) — Mock at the module boundary using `unittest.mock.patch` or `pytest-mock`'s `mocker` fixture.
3. **Framework imports** (FastAPI, Flask, Django) — Use framework-specific test clients (`TestClient`, `Flask.test_client`, Django's `TestCase`).
4. **Internal module imports** (other project files) — Mock only if the dependency has side effects or complex setup.

**Decision rule:** Mock at architectural boundaries (network, filesystem, database, external services), never at internal function boundaries. Testing with real internal logic catches integration bugs that mocks hide.

### Side Effects

Identify all side effects in the module:

- **Network calls:** `requests.get/post`, `httpx.AsyncClient`, `aiohttp`
- **Filesystem:** `open()`, `pathlib.Path.read_text/write_text`, `os.path`
- **Timers:** `time.time()`, `time.sleep()`, `datetime.now()`
- **Global state:** `os.environ`, module-level caches, singleton patterns
- **Database:** ORM queries, raw SQL, migration operations
- **External services:** Redis, Celery, message queues

Each side effect must be controlled in tests. See Phase 4 for mocking patterns.

### Complexity

Estimate cyclomatic complexity to determine test count:

| Complexity | Minimum Tests | Strategy |
|------------|---------------|----------|
| 1-3 (simple) | 2-3 | Happy path + 1-2 edge cases |
| 4-8 (moderate) | 4-6 | Each branch + boundary values |
| 9-15 (complex) | 6-10 | Full branch coverage + error paths |
| 16+ (very complex) | 10+ | Consider splitting the function |

### Prioritization

When generating tests for multiple targets, sort by:

1. **Criticality:** Entry points, auth, data handling, payment logic first
2. **Risk:** High-complexity functions with many branches
3. **Coverage gap:** Modules with zero existing tests
4. **Stability:** Prefer stable APIs over code marked as experimental

---

## Phase 2: Test Strategy Selection

Match each symbol to a test strategy based on its type and dependencies. The decision matrix below maps Python code types to strategies.

### Decision Matrix

| Code Type | Strategy | Test Focus | Framework Utilities |
|-----------|----------|------------|---------------------|
| Pure function | Input/output assertions | Transform correctness, edge cases | `@pytest.mark.parametrize` |
| Class / methods | Instance state transitions | Constructor, public methods, properties | Fixtures for instance creation |
| Async function | Async patterns with cleanup | Coroutine resolution, exceptions, timing | `@pytest.mark.asyncio`, `pytest-asyncio` |
| FastAPI route | Request/response via TestClient | Status codes, response shape, error handling | `httpx.AsyncClient`, `TestClient` |
| Flask route | Request/response via test_client | Status codes, response body, redirects | `app.test_client()` |
| Django view | Request/response via test client | Status codes, context, ORM changes | `django.test.Client`, `django.test.TestCase` |
| Data model / ORM | Validation and serialization | Field validation, constraints, serialization | `pytest.param`, factory fixtures |
| Generator / iterator | Iteration protocol | `next()`, `StopIteration`, `yield` values | Direct iteration assertions |

### Pure Functions

Test every pure function with input/output assertions. No mocks needed.

```python
# Source: utils/calculate.py
def calculate_discount(
    price: float,
    percent: float,
    mode: str = "percentage",
) -> float: ...


# Test strategy: exhaustive input/output matrix
@pytest.mark.parametrize(
    "price, percent, mode, expected",
    [
        (100, 10, "percentage", 90),
        (100, 5, "flat", 95),
        (0, 10, "percentage", 0),
        (50, 0, "percentage", 50),
        (-10, 10, "percentage", -9),
    ],
)
def test_calculate_discount(price, percent, mode, expected):
    assert calculate_discount(price, percent, mode) == expected
```

### Class Methods

Test constructor, public methods, and property access. Use a fixture to create fresh instances.

```python
# Source: services/cart.py
class ShoppingCart:
    def __init__(self) -> None: ...
    def add_item(self, item: Item) -> None: ...
    @property
    def total(self) -> float: ...


# Test strategy: fixture for fresh cart, test each method
@pytest.fixture
def cart():
    return ShoppingCart()


def test_add_item_appends_to_cart(cart):
    item = create_item(price=9.99)
    cart.add_item(item)
    assert len(cart.items) == 1
    assert cart.items[0] == item


def test_total_sums_item_prices(cart):
    cart.add_item(create_item(price=10.00))
    cart.add_item(create_item(price=5.50))
    assert cart.total == 15.50
```

### Async Functions

Test coroutine resolution, rejection, and cancellation with proper async markers.

```python
# Source: services/fetch_data.py
async def fetch_user_data(user_id: str) -> UserData: ...


# Test strategy: mock async boundary, test all coroutine states
@pytest.mark.asyncio
async def test_fetch_user_data_returns_data_on_success():
    mock_data = {"id": "1", "name": "Alice"}
    with mock.patch("services.fetch_data.httpx.AsyncClient") as mock_client:
        mock_response = mock.MagicMock()
        mock_response.json.return_value = mock_data
        mock_response.raise_for_status = mock.MagicMock()
        mock_client.return_value.__aenter__.return_value.get.return_value = mock_response

        result = await fetch_user_data("1")

        assert result == UserData(id="1", name="Alice")


@pytest.mark.asyncio
async def test_fetch_user_data_raises_on_network_error():
    with mock.patch("services.fetch_data.httpx.AsyncClient") as mock_client:
        mock_client.return_value.__aenter__.return_value.get.side_effect = httpx.ConnectError("fail")

        with pytest.raises(ConnectionError, match="fail"):
            await fetch_user_data("1")
```

### FastAPI Routes

Test the full request/response cycle using `httpx.AsyncClient` with the ASGI app.

```python
# Source: api/users.py
from fastapi import FastAPI

app = FastAPI()


@pytest.fixture
def client():
    return httpx.AsyncClient(app=app, base_url="http://test")


@pytest.mark.asyncio
async def test_create_user_returns_201(client):
    response = await client.post(
        "/users",
        json={"name": "Alice", "email": "alice@test.com"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Alice"
    assert body["email"] == "alice@test.com"
    assert "id" in body


@pytest.mark.asyncio
async def test_create_user_returns_422_for_invalid_input(client):
    response = await client.post("/users", json={})
    assert response.status_code == 422
```

### Flask Routes

Test using Flask's built-in test client.

```python
# Source: app.py
from flask import Flask

app = Flask(__name__)


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_get_users_returns_list(client):
    response = client.get("/users")
    assert response.status_code == 200
    assert isinstance(response.json, list)


def test_create_user_returns_201(client):
    response = client.post(
        "/users",
        json={"name": "Alice", "email": "alice@test.com"},
    )
    assert response.status_code == 201
    assert response.json["name"] == "Alice"
```

### Django Views

Test using Django's test client within pytest.

```python
# Source: views.py
from django.test import Client


@pytest.fixture
def django_client():
    return Client()


def test_user_list_returns_200(django_client):
    response = django_client.get("/users/")
    assert response.status_code == 200


def test_user_detail_returns_404_for_missing(django_client):
    response = django_client.get("/users/9999/")
    assert response.status_code == 404
```

### Data Models and ORM

Test validation, constraints, and serialization. Use factory fixtures for model instances.

```python
# Source: models.py
from pydantic import BaseModel, field_validator


class User(BaseModel):
    name: str
    email: str
    age: int

    @field_validator("age")
    @classmethod
    def age_must_be_positive(cls, v):
        if v < 0:
            raise ValueError("age must be positive")
        return v


# Test strategy: parametrize validation, test defaults, test serialization
def test_user_creation_with_valid_data():
    user = User(name="Alice", email="alice@test.com", age=30)
    assert user.name == "Alice"
    assert user.age == 30


def test_user_rejects_negative_age():
    with pytest.raises(ValueError, match="age must be positive"):
        User(name="Bob", email="bob@test.com", age=-1)


@pytest.mark.parametrize(
    "name, email, age",
    [
        ("", "a@b.com", 25),       # empty name
        ("Alice", "", 25),          # empty email
        ("Alice", "a@b.com", 0),    # zero age
        ("Alice", "a@b.com", 150),  # very old
    ],
)
def test_user_validation_edge_cases(name, email, age):
    # These should succeed or raise specific errors
    try:
        User(name=name, email=email, age=age)
    except ValueError:
        pass  # Expected for invalid inputs
```

---

## Phase 3: Data Generation

### Equivalence Class Partitioning

Divide the input space into equivalence classes. One test per class is sufficient — additional tests in the same class provide diminishing returns.

```python
# For a function that processes ages (0-150):
# Class 1: Negative (invalid) → -1
# Class 2: Zero (boundary) → 0
# Class 3: Valid range (1-17, minor) → 12
# Class 4: Valid range (18-64, adult) → 35
# Class 5: Valid range (65-150, senior) → 75
# Class 6: Over maximum (invalid) → 200

@pytest.mark.parametrize(
    "age, expect_error",
    [
        (-1, True),
        (0, False),
        (12, False),
        (35, False),
        (75, False),
        (200, True),
    ],
)
def test_process_age(age, expect_error):
    if expect_error:
        with pytest.raises(ValueError):
            process_age(age)
    else:
        result = process_age(age)
        assert result is not None
```

### Boundary Value Analysis

Test at the boundaries of each equivalence class. For numeric ranges `[a, b]`, test `a-1`, `a`, `a+1`, `b-1`, `b`, `b+1`.

```python
# For a function accepting 1-100 inclusive:
@pytest.mark.parametrize(
    "value, description",
    [
        (0, "just below minimum"),
        (1, "minimum boundary"),
        (2, "just above minimum"),
        (99, "just below maximum"),
        (100, "maximum boundary"),
        (101, "just above maximum"),
    ],
)
def test_validates_range(value, description):
    if 1 <= value <= 100:
        assert validate_range(value) is True
    else:
        with pytest.raises(ValueError):
            validate_range(value)
```

### Factory Fixtures

Always use factory fixtures for test data. Never hardcode dicts or objects inline in multiple tests.

```python
# Factory fixture pattern — generates valid data with sensible defaults
@pytest.fixture
def create_user():
    def _create(**overrides):
        defaults = {
            "id": "user-1",
            "name": "Test User",
            "email": "test@example.com",
            "role": "viewer",
            "created_at": "2024-01-15T00:00:00Z",
        }
        defaults.update(overrides)
        return User(**defaults)
    return _create


# Usage — each test specifies only what it needs
def test_admin_can_delete_resources(create_user):
    admin = create_user(role="admin")
    assert can_delete(admin) is True


def test_viewer_cannot_delete_resources(create_user):
    viewer = create_user(role="viewer")
    assert can_delete(viewer) is False


# List factory — generates multiple distinct items
@pytest.fixture
def create_user_list(create_user):
    def _create_list(count: int, **overrides):
        return [create_user(id=f"user-{i+1}", **overrides) for i in range(count)]
    return _create_list
```

### Factory Boy Integration

For Django or SQLAlchemy models, prefer Factory Boy for model instance generation:

```python
# factories.py
import factory
from .models import User


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User

    name = factory.Sequence(lambda n: f"User {n}")
    email = factory.LazyAttribute(lambda obj: f"{obj.name.lower().replace(' ', '.')}@test.com")
    role = "viewer"


# Test usage
@pytest.mark.django_db
def test_admin_can_delete_resources():
    admin = UserFactory(role="admin")
    assert can_delete(admin) is True
```

### Property-Based Testing with Hypothesis

For complex logic where enumerating cases is impractical, use property-based testing:

```python
from hypothesis import given, strategies as st


@given(st.lists(st.integers()))
def test_sort_output_length_equals_input_length(arr):
    assert len(sort(arr)) == len(arr)


@given(st.lists(st.integers()))
def test_sort_output_is_ordered(arr):
    result = sort(arr)
    for i in range(1, len(result)):
        assert result[i] >= result[i - 1]
```

---

## Phase 4: Test Writing

### Naming Convention

Test names must describe the specific scenario and expected outcome. In pytest, use `test_` prefixed function names or descriptive `describe`-style class names. Follow the pattern: `test_{unit}_{behavior}_when_{condition}`.

```python
# BAD — vague
def test_works():
def test_handles_error():

# GOOD — specific
def test_calculate_discount_returns_zero_when_price_is_zero():
def test_fetch_user_raises_network_error_when_fetch_returns_503():
def test_cart_shows_empty_state_when_items_list_is_empty():
```

### Arrange-Act-Assert Structure

Every test body must follow this three-part structure. Separate each section with a blank line.

```python
def test_calculate_total_applies_bulk_discount_for_10_plus_items():
    # Arrange
    items = create_item_list(12, price=10)

    # Act
    total = calculate_total(items)

    # Assert
    assert total == 108  # 12 * 10 * 0.9
```

### Single Assertion Per Concept

Each test should verify one logical concept. Multiple `assert` calls that verify different aspects of the same concept are fine. Multiple unrelated assertions belong in separate tests.

```python
# GOOD — multiple asserts, one concept (response shape)
def test_create_user_returns_user_with_generated_id(create_user):
    user = create_user(name="Alice")
    assert user.id is not None
    assert user.name == "Alice"


# BAD — two unrelated concepts in one test
def test_create_user_works(create_user, mock_email):
    user = create_user(name="Alice")
    assert user.name == "Alice"              # Concept 1: name
    mock_email.assert_called_once_with(user)  # Concept 2: side effect
```

### Mocking Guidelines

**Rule 1: Mock at boundaries, not internals.** Mock external services (API, database, filesystem), never internal functions within the same module.

```python
# BAD — mocking internal helper
with mock.patch("module.validate_input", return_value=True):
    # Testing through a fake

# GOOD — mocking external dependency
with mock.patch("module.httpx.AsyncClient") as mock_client:
    mock_client.return_value.__aenter__.return_value.get.return_value = mock_response
    # Testing real internal logic
```

**Rule 2: Use `pytest-mock` for cleaner mock lifecycle.** The `mocker` fixture automatically cleans up patches.

```python
def test_fetches_data_from_api(mocker):
    mock_get = mocker.patch("module.httpx.get", return_value=mock_response)

    result = fetch_data("endpoint")

    mock_get.assert_called_once_with("endpoint")
    assert result == expected_data
```

**Rule 3: Reset mocks between tests.** Use `mocker` (auto-reset) or explicit `mock.patch` teardown. When using raw `unittest.mock`, ensure cleanup in `finally` blocks or `yield` fixtures.

```python
@pytest.fixture(autouse=True)
def reset_mocks(mocker):
    # mocker fixture handles cleanup automatically
    yield
    # No manual cleanup needed — pytest-mock resets all patches
```

**Rule 4: Assert on mock calls only when testing collaboration.** If the test's purpose is to verify a side effect (e.g., "sends analytics event"), asserting on mock calls is appropriate. If the test's purpose is to verify output, assert on the return value instead.

### Mocking Patterns Reference

| Concern | Pattern | Example |
|---------|---------|---------|
| Patch module-level function | `mocker.patch("module.func")` | `mocker.patch("app.send_email")` |
| Patch class method | `mocker.patch.object(obj, "method")` | `mocker.patch.object(client, "get")` |
| Patch environment variable | `mocker.patch.dict(os.environ, {...})` | `mocker.patch.dict(os.environ, {"API_KEY": "test"})` |
| Async mock | `mocker.AsyncMock()` | `mocker.patch("module.async_func", return_value=val)` |
| Property mock | `mocker.patch.object(obj, "prop", new_callable=mocker.PropertyMock)` | Mock a property getter |
| Context manager mock | `mocker.MagicMock().__enter__()` | Mock file handles, DB connections |

### Fixture Strategies

#### Scope Management

Choose fixture scope based on creation cost and test isolation needs:

| Scope | When to Use | Example |
|-------|-------------|---------|
| `function` (default) | Most fixtures — fresh per test | Test client, database session, temp directory |
| `class` | Shared read-only setup for a group of tests | Reference data, static configuration |
| `module` | Expensive setup that is truly read-only | App instance, schema compilation |
| `session` | Very expensive global resources | Database container, external service mock |

**Anti-pattern:** Using `scope="session"` for mutable fixtures. Session-scoped fixtures must be immutable or properly reset. If a test mutates a session-scoped fixture, all subsequent tests see the mutation.

```python
# GOOD — session scope for immutable reference data
@pytest.fixture(scope="session")
def app_config():
    return load_config("test")


# BAD — session scope for mutable state
@pytest.fixture(scope="session")
def database():
    db = create_database()
    yield db
    db.drop()  # If any test inserts data, other tests see it
```

#### Fixture Composition

Nest fixtures to build complex test state from simple building blocks:

```python
@pytest.fixture
def user(create_user):
    return create_user(role="admin")


@pytest.fixture
def authenticated_client(client, user):
    client.headers["Authorization"] = f"Bearer {generate_token(user)}"
    return client


# Test uses the composed fixture directly
@pytest.mark.asyncio
async def test_admin_can_create_user(authenticated_client):
    response = await authenticated_client.post("/users", json={"name": "Bob"})
    assert response.status_code == 201
```

#### conftest.py Organization

- **`conftest.py` at project root:** Fixtures shared across all test directories
- **`conftest.py` in subdirectory:** Fixtures scoped to that directory and its children
- **Rule:** A fixture should live in the deepest conftest.py that still reaches all consumers. Do not put fixtures in the root conftest if only one subpackage uses them.

```
project/
├── conftest.py          # db_session, app, create_user (shared)
├── tests/
│   ├── conftest.py      # client, authenticated_client (test-wide)
│   ├── unit/
│   │   ├── conftest.py  # mock_external_api (unit-only)
│   │   └── test_calc.py
│   └── api/
│       ├── conftest.py  # api_client (API-only)
│       └── test_users.py
```

---

## Phase 5: Verification Loop

The verification loop iterates: compile → run → coverage → mutation. Each step has a specific failure mode and fix protocol.

### Step 1: Import and Type Verification

Run the Python import checker and mypy/pyright on generated test files:

```bash
python -c "import tests.test_module"  # Verify imports resolve
mypy tests/test_module.py --no-error-summary  # Type check if configured
```

**Failure protocol:**
- Import error → Fix the import path; check if the source file exists and exports the symbol; verify `__init__.py` files exist in package directories
- Type error → Fix the test's types; do not change source types to accommodate the test
- Missing dependency → Install the missing package; add to requirements-dev.txt or pyproject.toml [project.optional-dependencies]
- Syntax error → Fix the test code structure (indentation, colons, decorators)

**Maximum iterations:** 3. After 3 import failures on the same test, present to the user for manual resolution.

### Step 2: Execution

Run the generated tests:

```bash
pytest tests/test_module.py -v --tb=short
```

**Failure protocol:**
- Test assertion fails → Analyze the failure message. Determine if the test expectation is wrong or the source has a bug. Fix the test, never the source.
- Fixture not found → Check conftest.py placement; ensure the fixture name matches; verify scope compatibility
- `@pytest.mark.asyncio` missing → Add the marker to async test functions
- Timeout → Check for unmocked async operations. Add proper `await` or mock slow dependencies.
- Collection error → Check for syntax errors, missing `test_` prefix, or conflicting `__init__.py`

**Critical rule:** Never modify source code to make a test pass. If the source has a genuine bug discovered during test generation, note it in the test file as a comment and create a passing test that documents the current (possibly buggy) behavior.

```python
# NOTE: Source returns -1 for empty arrays, which may be a bug.
# This test documents current behavior for regression detection.
def test_find_max_returns_negative_one_for_empty_array():
    assert find_max([]) == -1
```

**Maximum iterations:** 3 fix attempts per test. After 3 failures, skip the test and report it for manual resolution.

### Step 3: Coverage Analysis

Measure coverage contribution of the new tests:

```bash
pytest tests/test_module.py --cov=src/module --cov-report=term-missing
```

**Coverage thresholds:**
- Below 50% branch coverage → Add tests for uncovered branches
- Below 70% function coverage → Add tests for untested functions
- Below 60% line coverage → Add tests for uncovered logic paths

**Anti-pattern to avoid:** Do not add tests solely to inflate coverage numbers. Each test must verify meaningful behavior. A test that calls a function without asserting anything is worse than no test at all.

### Step 4: Mutation Testing (Optional)

If mutation testing is configured (e.g., mutmut), run it on the new tests to measure assertion strength:

```bash
mutmut run --paths-to-mutate src/module.py
```

**Mutation survivors → strengthen assertions:**
- Surviving mutation on a conditional → Add a test that exercises the opposite branch
- Surviving mutation on a return value → Make the assertion more specific (exact value, not `is not None`)
- Surviving mutation on a boundary → Add a boundary value test

---

## Phase 6: Quality Audit

Every generated test is scored on a 0-100 scale across five dimensions. The minimum acceptable score is 70.

### Assertion Quality (0-30 points)

Measures whether assertions actually verify meaningful behavior.

| Score Range | Characteristics |
|-------------|-----------------|
| **25-30** | Specific values with `==`, `assertEqual`, or pytest's plain `assert`; edge cases covered; error paths tested with `pytest.raises`; no bare `assert True` or `assert result is not None` when exact value is knowable |
| **18-24** | Mostly specific assertions; may miss some edge cases; 1-2 broad assertions on non-critical paths |
| **10-17** | Mix of specific and broad; missing edge cases; some `assert result is not None` where exact value is knowable |
| **0-9** | Predominantly `assert result`, `assert True`, or `is not None`; missing error assertions |

**Scoring adjustments:**
- +3 per distinct edge case assertion
- +2 per error path assertion (using `pytest.raises`)
- -5 per bare `assert result` on a non-boolean value
- -8 per `assert True` or tautological assertion
- -10 per assertion comparing a value to itself

**pytest assertion model note:** Python's `assert` statement with rich comparison provides detailed error output natively. Prefer plain `assert` over `unittest` assertion methods (`assertEqual`, `assertTrue`) for readability. Use `pytest.raises` for exception testing, not bare `try/except` with `assert False`.

```python
# GOOD — pytest-native assertion style
def test_discount_applies_percentage():
    assert calculate_discount(100, 20) == 80

# ACCEPTABLE but less idiomatic
def test_discount_applies_percentage():
    self.assertEqual(calculate_discount(100, 20), 80)
```

### Test Structure (0-20 points)

Measures adherence to arrange-act-assert and naming conventions.

| Score Range | Characteristics |
|-------------|-----------------|
| **16-20** | Clear AAA separation; descriptive `test_` prefixed names; single concept per test; no copy-paste structure |
| **11-15** | AAA mostly present; names are adequate; may test 2 concepts in one test |
| **6-10** | AAA inconsistent; vague names; multiple unrelated assertions; significant duplication |
| **0-5** | No structure; test names are generic (`test_1`, `test_it`); large copy-pasted blocks |

**Scoring adjustments:**
- +2 per test with descriptive name following the `test_{unit}_{behavior}_when_{condition}` pattern
- -3 per test with a name like `test_works`, `test_1`, or `test_function`
- -5 per test with no AAA separation at all

### Independence (0-20 points)

Measures whether tests can run in any order, in isolation, without shared mutable state.

| Score Range | Characteristics |
|-------------|-----------------|
| **16-20** | All tests self-contained; fixtures provide fresh state; no shared mutable variables; proper mock cleanup via `mocker` or `yield` fixtures |
| **11-15** | Mostly independent; may share a read-only fixture; minor cleanup gaps |
| **6-10** | Some tests depend on shared state; cleanup present but incomplete; one test may affect another |
| **0-5** | Tests must run in order; shared mutable state across tests; no cleanup; module-level mutations |

**Scoring adjustments:**
- +3 per factory fixture used instead of hardcoded objects
- -5 per module-level mutable variable modified across tests without fixture reset
- -10 per test that only passes when run after another specific test
- -15 per `@pytest.mark.skip` or `pytest.skip()` left in committed code without a linked issue

### Coverage Value (0-15 points)

Measures whether tests cover meaningful paths, not just the happy path.

| Score Range | Characteristics |
|-------------|-----------------|
| **12-15** | Happy path + error paths + boundary values; tests meaningful branches; no coverage-only tests |
| **8-11** | Happy path + some error paths; may miss boundary values |
| **4-7** | Mostly happy path; error paths untested; tests only the obvious cases |
| **0-3** | Only happy path; tests that call code without asserting; coverage theater |

**Scoring adjustments:**
- +3 per error path test (using `pytest.raises` or testing error return values)
- +2 per boundary value test
- -5 per test that calls a function but has no assertion on the result
- -8 per test that exists only to inflate line coverage

### Maintainability (0-15 points)

Measures how easy tests are to understand, modify, and extend.

| Score Range | Characteristics |
|-------------|-----------------|
| **12-15** | Factory fixtures for all data; clear intent; no magic numbers; no hardcoded IDs/dates; follows project conventions |
| **8-11** | Some hardcoded data; mostly clear intent; may have a few magic numbers |
| **4-7** | Significant hardcoded data; unclear test purpose; inconsistent patterns |
| **0-3** | All data hardcoded; copy-pasted across tests; no factories; magic numbers everywhere |

**Scoring adjustments:**
- +3 per factory fixture with sensible defaults and override support
- -2 per hardcoded date string that should use a factory or fixture
- -3 per magic number without an explanatory comment or named constant
- -5 per block of data copy-pasted between tests

### Score Examples

**90+ test (exemplary):**

```python
def test_calculate_discount_returns_reduced_price_when_percentage_is_valid(create_cart, create_item):
    cart = create_cart(items=[create_item(price=100)])

    result = calculate_discount(cart, 20)

    assert result == 80
```
- Assertion: 28/30 — specific value, meaningful scenario
- Structure: 18/20 — clear AAA, descriptive name
- Independence: 18/20 — factory fixtures, no shared state
- Coverage: 14/15 — tests core calculation logic
- Maintainability: 14/15 — factories, no magic numbers

**50 test (mediocre):**

```python
def test_discount_works():
    cart = {"items": [{"price": 100, "id": "item-1", "name": "Widget"}], "total": 100}
    result = calculate_discount(cart, 20)
    assert result
```
- Assertion: 8/30 — bare `assert result` on a number, no edge cases
- Structure: 10/20 — vague name, no clear AAA
- Independence: 15/20 — no shared state but hardcoded data
- Coverage: 8/15 — only happy path
- Maintainability: 9/15 — hardcoded dict

**<30 test (poor):**

```python
def test_1():
    assert calculate_discount({"items": [], "total": 0}, 20)
```
- Assertion: 3/30 — bare `assert` on what should be 0
- Structure: 2/20 — generic name, no AAA
- Independence: 10/20 — no shared state but inline data
- Coverage: 5/15 — empty input only
- Maintainability: 5/15 — inline dict, no factory

### Auto-Commit Thresholds

| Score | Action |
|-------|--------|
| **≥ 85** | Auto-commit. High quality, no review needed. |
| **70-84** | Auto-commit with summary comment listing the quality score. |
| **50-69** | Present to user for review before committing. Flag specific low-scoring dimensions. |
| **< 50** | Do not commit. Regenerate or present for manual writing. |

---

## Phase 7: HITL Gate

Present a structured summary to the user before committing. The summary must include all of the following sections.

### Test Summary

```
Generated: 12 tests across 3 files
  - tests/unit/test_calculate.py: 5 tests (score: 88)
  - tests/api/test_users.py: 4 tests (score: 76)
  - tests/unit/test_models.py: 3 tests (score: 82)
```

### Coverage Delta

```
Coverage change (before → after):
  - src/utils/calculate.py: 0% → 92% branch, 100% function
  - src/api/users.py: 45% → 78% branch, 100% function
  - src/models.py: 0% → 85% branch, 100% function
```

### Quality Scores

```
Average quality score: 82/100
  - Highest: test_calculate.py (88) — strong assertions, good edge case coverage
  - Lowest: test_users.py (76) — missing error state test for 500 response
```

### Flagged Items

Items requiring manual review:

```
⚠️  tests/api/test_users.py: No test for 500 internal server error response
⚠️  tests/unit/test_models.py: Test skipped after 3 failed fix attempts (fixture issue)
```

### Auto-Commit Decision

Based on scores:
- All tests ≥ 70: **Auto-commit.** Summary displayed for awareness.
- Any test 50-69: **Auto-commit with flag.** User can review and request regeneration.
- Any test < 50: **Hold for review.** User must approve before commit.

---

## Python-Specific Anti-Patterns

These anti-patterns complement the general catalog in `references/anti-patterns.md` with Python/pytest-specific guidance. The generation spoke must verify generated tests are free of these patterns.

### Critical (must fix)

- **Missing `@pytest.mark.asyncio`** on async test functions — causes `RuntimeWarning: coroutine was never awaited` and the test appears to pass without executing. Every `async def test_*` function must have the marker (or `pytest-asyncio` auto mode must be configured).
- **Missing `__init__.py`** in test directories — pytest discovers tests without it, but imports between test modules and conftest.py may fail silently or produce unexpected path resolution.
- **Fixture scope misuse** — Using `scope="session"` for fixtures that mutate state (database inserts, file writes, env var changes). Session-scoped fixtures must be immutable or properly reset.

### High (should fix)

- **`monkeypatch` without cleanup** — Using `monkeypatch.setattr()` or `monkeypatch.setenv()` without the built-in cleanup that `monkeypatch` provides (it auto-cleans at function end). If using raw `mock.patch()`, ensure proper teardown.
- **Test interdependence via module state** — Tests that modify module-level variables (`module.cache = {}`) or class-level state without resetting between tests. Use fixtures to provide fresh instances.
- **Bare `try/except` in tests** — Catching exceptions without re-raising or asserting. Use `pytest.raises` instead:
  ```python
  # BAD
  try:
      risky_operation()
  except Exception:
      pass  # Silently passes

  # GOOD
  with pytest.raises(ValueError, match="expected message"):
      risky_operation()
  ```
- **Missing `@pytest.mark.django_db`** — Django ORM tests that access the database without the `django_db` marker will fail with `TransactionManagementError` or silently use the real database.

### Medium (should minimize)

- **Using `unittest.TestCase` in pytest** — Mixing `unittest.TestCase` classes with pytest fixtures. Pytest fixtures do not work with `unittest.TestCase`. Use plain functions and pytest fixtures instead.
- **Overly broad `patch.object`** — Patching `requests.get` globally instead of patching the specific module's import path. Patch where the function is *used*, not where it is *defined*:
  ```python
  # BAD — patches globally
  mocker.patch("requests.get")

  # GOOD — patches where it's used
  mocker.patch("myapp.service.requests.get")
  ```
- **Snapshot drift in `assert result == expected`** — Large expected dicts that are copy-pasted from actual output. When the output format changes, these become maintenance burden. Use targeted assertions instead.

### Low (style)

- **Missing `test_` prefix** — pytest discovers test functions by name convention. Functions without the prefix are silently skipped.
- **Using `print` instead of logging in test helpers** — `print` output is captured by pytest and only shown with `-s` flag. Use `capfd` or `capsys` fixtures when testing stdout/stderr.
- **Hardcoded file paths** — Using `/tmp/test-*` or other OS-specific paths. Use `tmp_path` fixture for temporary files:
  ```python
  def test_writes_file(tmp_path):
      output = tmp_path / "result.json"
      write_results(output)
      assert output.exists()
  ```

---

## Framework-Specific Patterns

### FastAPI Test Client (Complete Example)

```python
import pytest
import httpx
from app.main import app
from app.database import get_db


# Override database dependency for testing
@pytest.fixture
def test_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(test_db):
    app.dependency_overrides[get_db] = lambda: test_db
    with httpx.AsyncClient(app=app, base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_list_users_empty(client):
    response = await client.get("/users")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_create_user_returns_201(client):
    response = await client.post(
        "/users",
        json={"name": "Alice", "email": "alice@test.com"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Alice"
    assert "id" in body


@pytest.mark.asyncio
async def test_create_user_rejects_duplicate_email(client):
    await client.post("/users", json={"name": "Alice", "email": "alice@test.com"})
    response = await client.post(
        "/users",
        json={"name": "Bob", "email": "alice@test.com"},
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_get_user_returns_404_for_missing(client):
    response = await client.get("/users/nonexistent-id")
    assert response.status_code == 404
```

### Flask Test Client (Complete Example)

```python
import pytest
from app import create_app


@pytest.fixture
def app():
    app = create_app(testing=True)
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"
    with app.app_context():
        from app.models import db
        db.create_all()
        yield app
        db.drop_all()


@pytest.fixture
def client(app):
    with app.test_client() as client:
        yield client


def test_list_users_empty(client):
    response = client.get("/users")
    assert response.status_code == 200
    assert response.json == []


def test_create_user_returns_201(client):
    response = client.post(
        "/users",
        json={"name": "Alice", "email": "alice@test.com"},
    )
    assert response.status_code == 201
    assert response.json["name"] == "Alice"


def test_create_user_rejects_invalid_email(client):
    response = client.post(
        "/users",
        json={"name": "Alice", "email": "not-an-email"},
    )
    assert response.status_code == 400


def test_get_user_returns_404_for_missing(client):
    response = client.get("/users/9999")
    assert response.status_code == 404
```

### Django Test Patterns (Complete Example)

```python
import pytest
from django.test import Client
from app.models import User


@pytest.fixture
def django_client():
    return Client()


@pytest.fixture
def create_db_user(db):
    def _create(**overrides):
        defaults = {
            "username": "testuser",
            "email": "test@example.com",
            "role": "viewer",
        }
        defaults.update(overrides)
        return User.objects.create_user(**defaults)
    return _create


@pytest.mark.django_db
def test_list_users_empty(django_client):
    response = django_client.get("/users/")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.django_db
def test_create_user_returns_201(django_client):
    response = django_client.post(
        "/users/",
        {"username": "alice", "email": "alice@test.com"},
        content_type="application/json",
    )
    assert response.status_code == 201


@pytest.mark.django_db
def test_user_detail_returns_correct_data(django_client, create_db_user):
    user = create_db_user(username="alice")
    response = django_client.get(f"/users/{user.pk}/")
    assert response.status_code == 200
    assert response.json()["username"] == "alice"


@pytest.mark.django_db
def test_user_detail_returns_404_for_missing(django_client):
    response = django_client.get("/users/9999/")
    assert response.status_code == 404
```

---

## Quality Audit Checklist

This checklist maps to the anti-pattern categories defined in `references/anti-patterns.md` plus the Python-specific anti-patterns above. The generate spoke must verify generated tests pass all checks before presenting them to the user.

### Critical Checks (must pass — zero tolerance)

- [ ] **No tautological assertions** — No test compares a value to itself; no `assert True`
- [ ] **No hardcoded secrets** — No real-looking passwords, API keys, or tokens
- [ ] **No missing assertions** — Every `test_` function contains at least one `assert` or `pytest.raises`
- [ ] **Async tests have `@pytest.mark.asyncio`** — Every `async def test_*` has the marker (or auto mode is configured)

### High Checks (should pass — flag if present)

- [ ] **No sleep-based waits** — No `time.sleep()` with arbitrary delays in tests; use `mocker.patch` for time-dependent code
- [ ] **No test interdependencies** — No shared mutable state without fixture reset
- [ ] **No empty except blocks** — Every `except` asserts on or re-raises the error; prefer `pytest.raises`
- [ ] **No flaky indicators** — `datetime.now()`, `random.random()`, and network calls are properly mocked
- [ ] **Django tests have `@pytest.mark.django_db`** — All tests accessing the ORM have the marker

### Medium Checks (should minimize — acceptable in limited cases)

- [ ] **No overly broad assertions** — No bare `assert result` on non-boolean values, no `assert result is not None` when exact value is knowable
- [ ] **No implementation coupling** — No accessing `_private` attributes, no `obj.__dict__` inspection
- [ ] **Mocks target correct path** — `mocker.patch` targets where the function is used, not where it is defined

### Low Checks (style — address when convenient)

- [ ] **No duplicate test logic** — No near-identical test blocks; use `@pytest.mark.parametrize` for parameterized cases
- [ ] **Meaningful test names** — No `test_1`, `test_function`, or `test_it_works` names
- [ ] **Factory fixtures for data** — No hardcoded dicts repeated across tests
- [ ] **Proper cleanup** — `yield` fixtures clean up resources; `tmp_path` used for temp files; environment patches restored
- [ ] **Using pytest-native assertions** — `assert x == y` not `self.assertEqual(x, y)`

---

## Cross-Reference

This guide is consumed by:
- **Python generation spoke** (`references/spoke-generate-python.md`) — Phase 4 (test writing patterns) and Phase 7 (quality audit scoring)
- **Anti-pattern catalog** (`references/anti-patterns.md`) — Quality audit checklist maps to the 20 anti-pattern categories; the generate spoke must ensure generated tests are free of all critical and high severity anti-patterns
- **Config schema** (`references/config-schema.md`) — Coverage thresholds and framework settings from project configuration
- **Python decision tree** (`references/python-decision-tree.md`) — Framework selection for Python projects, which determines which patterns in this guide to apply
