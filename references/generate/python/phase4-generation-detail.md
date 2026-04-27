# Phase 4 — Test Generation Detail (Python)

On-demand sub-file for `spoke-generate-python.md`. Contains complete mocking patterns, factory functions, parametrize examples, and the full well-generated test file example.

---

## Mocking patterns

### Using pytest-mock (preferred when available)

```python
def test_fetches_data_from_api(mocker):
    mock_get = mocker.patch("module.httpx.get", return_value=mock_response)

    result = fetch_data("endpoint")

    mock_get.assert_called_once_with("endpoint")
    assert result == expected_data
```

### Using raw unittest.mock (fallback)

```python
from unittest.mock import patch, MagicMock

def test_fetches_data_from_api():
    with patch("module.httpx.get") as mock_get:
        mock_get.return_value = mock_response

        result = fetch_data("endpoint")

        mock_get.assert_called_once_with("endpoint")
        assert result == expected_data
```

### Async mocking

```python
@pytest.mark.asyncio
async def test_async_fetch(mocker):
    mock_client = mocker.AsyncMock()
    mock_client.get.return_value = mock_response
    mocker.patch("module.httpx.AsyncClient", return_value=mock_client)

    result = await fetch_user("1")

    assert result == expected_data
```

### Environment variable mocking

```python
def test_uses_api_key_from_env(mocker):
    mocker.patch.dict("os.environ", {"API_KEY": "test-key-123"})

    result = get_api_key()

    assert result == "test-key-123"
```

### Database dependency override (FastAPI)

```python
@pytest.fixture
def client(test_db):
    app.dependency_overrides[get_db] = lambda: test_db
    with httpx.AsyncClient(app=app, base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()
```

---

## Factory functions

Always generate factory functions for test data. Never hardcode dicts or objects inline in multiple tests.

```python
def create_user(**overrides):
    defaults = {
        "id": "user-1",
        "name": "Test User",
        "email": "test@example.com",
        "role": "viewer",
        "created_at": "2024-01-15T00:00:00Z",
    }
    defaults.update(overrides)
    return defaults


def create_item_list(count, **overrides):
    return [
        {"id": f"item-{i+1}", "name": f"Item {i+1}", "price": 10, **overrides}
        for i in range(count)
    ]
```

For Pydantic models:

```python
def create_user_model(**overrides):
    defaults = {
        "name": "Test User",
        "email": "test@example.com",
        "role": "viewer",
    }
    defaults.update(overrides)
    return User(**defaults)
```

---

## Parametrize patterns

Use `@pytest.mark.parametrize` for data-driven testing of the same behavior with different inputs:

```python
@pytest.mark.parametrize(
    "price, percent, expected",
    [
        (100, 20, 80),
        (100, 0, 100),
        (50, 50, 25),
        (0, 20, 0),
    ],
)
def test_calculate_discount(price, percent, expected):
    assert calculate_discount(price, percent) == expected
```

For exception-testing with parametrize:

```python
@pytest.mark.parametrize(
    "price, percent",
    [
        (-10, 20),
        (100, -5),
        (100, 150),
    ],
)
def test_calculate_discount_raises_for_invalid_input(price, percent):
    with pytest.raises(ValueError):
        calculate_discount(price, percent)
```

---

## Complete example: well-generated test file

This is the target quality level for every generated file:

```python
import pytest
from unittest.mock import MagicMock

from pricing import calculate_discount, apply_bulk_discount


def create_cart(**overrides):
    defaults = {"items": [], "total": 0}
    defaults.update(overrides)
    return defaults


def create_item(**overrides):
    defaults = {"id": "item-1", "name": "Widget", "price": 10}
    defaults.update(overrides)
    return defaults


class TestCalculateDiscount:
    def test_returns_reduced_price_when_percentage_is_valid(self):
        cart = create_cart(items=[create_item(price=100)])
        assert calculate_discount(cart, 20) == 80

    def test_returns_full_price_when_discount_is_zero(self):
        cart = create_cart(items=[create_item(price=50)])
        assert calculate_discount(cart, 0) == 50

    def test_raises_when_discount_exceeds_100(self):
        cart = create_cart(items=[create_item(price=100)])
        with pytest.raises(ValueError, match="cannot exceed 100"):
            calculate_discount(cart, 150)

    def test_returns_zero_when_cart_total_is_zero(self):
        cart = create_cart(items=[])
        assert calculate_discount(cart, 20) == 0


class TestApplyBulkDiscount:
    def test_applies_10_percent_discount_for_10_plus_items(self):
        items = [{"id": f"item-{i}", "name": f"Item {i}", "price": 10} for i in range(12)]
        assert apply_bulk_discount(items) == 108

    def test_returns_full_total_for_fewer_than_10_items(self):
        items = [{"id": f"item-{i}", "name": f"Item {i}", "price": 10} for i in range(5)]
        assert apply_bulk_discount(items) == 50
```

**Note on test organization:** Use plain `test_` functions for simple cases. Use `class Test*` grouping when tests share setup via `@pytest.fixture` or when logically grouping tests for the same class/method. Do NOT subclass `unittest.TestCase` — use pytest-native patterns exclusively.
