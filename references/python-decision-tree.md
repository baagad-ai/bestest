# Python Framework Decision Tree

Complete framework selection decision tree for Python repositories. The detection engine uses this tree to populate the `testFrameworks` and `e2eFramework` recommendations in the StackProfile when the primary language is Python.

## Decision Flow

### Step 1: Check for Existing pytest

```
Has pytest.ini, [tool.pytest] in pyproject.toml, or "pytest" in requirements?
├─ YES → Check customization depth
│         ├─ Has pytest plugins (pytest-asyncio, pytest-django, etc.)? → Keep pytest
│         ├─ Has conftest.py with complex fixtures (DB, auth, mocks)? → Keep pytest
│         ├─ Has >50 test files already? → Keep pytest (migration cost high)
│         └─ Simple setup with <20 test files? → Keep pytest (already optimal)
│
│         Rationale: pytest is the de facto standard for Python testing. There is
│         no reason to migrate away from pytest — the decision is about which
│         plugins and patterns to add, not whether to switch frameworks.
│
│         Coverage: pytest-cov (wraps coverage.py)
│         Config file: pyproject.toml [tool.pytest.ini_options] or pytest.ini
│
└─ NO → Proceed to Step 2
```

### Step 2: Check for unittest Usage

```
Has "import unittest" in test files or unittest test discovery configured?
├─ YES → Evaluate migration feasibility
│         ├─ Heavy use of unittest.TestCase subclassing? → Keep unittest, suggest
│         │   pytest as runner (pytest can run unittest tests)
│         ├─ Simple test classes? → Recommend pytest (can run existing unittest
│         │   tests unchanged while adding pytest-native tests)
│         └─ Has TestLoader / TestSuite composition? → Keep unittest, add pytest runner
│
│         Rationale: pytest can discover and run unittest tests. This gives a
│         migration path without rewriting existing tests. New tests use pytest style.
│
│         If keeping unittest:
│         Coverage: coverage.py (via `coverage run -m unittest`)
│         Config file: None (unittest uses discovery)
│
└─ NO → Proceed to Step 3
```

### Step 3: Default Recommendation

```
No existing test framework detected.
├─ Any Python project → pytest (industry standard, richest plugin ecosystem)
└─ Reasoning: pytest is the universal choice for Python testing. Its fixture
    model, parametrize decorator, plugin architecture, and assertion introspection
    make it strictly superior to unittest for new projects. Even projects that
    use unittest for legacy reasons often run tests via pytest.
```

### Step 4: Async Framework Consideration

```
Does the project use async? (asyncio, anyio, async frameworks)
├─ YES → Add pytest-asyncio plugin
│         Config: asyncio_mode = "auto" in pytest config
│         Mark: @pytest.mark.asyncio on async tests (or auto mode)
│
│         Async framework specifics:
│         ├─ FastAPI → httpx.AsyncClient for test client, pytest-asyncio
│         ├─ asyncio stdlib → pytest-asyncio
│         ├─ anyio → pytest-anyio plugin
│         └─ Celery → Use pytest + Celery fixtures (pytest-celery or custom)
│
│         Rationale: Async tests need a dedicated event loop per test. pytest-asyncio
│         handles loop lifecycle. Without it, async tests silently don't await.
│
└─ NO → Standard synchronous test setup
```

### Step 5: Web Framework Specialization

```
Which web framework is detected?
├─ FastAPI → pytest + httpx (TestClient wraps httpx.AsyncClient)
│         Config: pytest-asyncio + httpx
│         Test client: from fastapi.testclient import TestClient
│         Async test client: httpx.AsyncClient(app=app, base_url="http://test")
│         Pattern: fixture that yields app + client
│
├─ Flask → pytest + pytest-flask (or plain flask test client)
│         Test client: app.test_client()
│         Pattern: fixture that creates app with TESTING=True
│         Fixtures: client, app fixtures from pytest-flask
│
├─ Django → pytest-django (or Django's TestCase)
│         Config: DJANGO_SETTINGS_MODULE in pytest config
│         Option 1: pytest-django with @pytest.mark.django_db
│         Option 2: Django TestCase (subclass of unittest.TestCase)
│         Recommend: pytest-django for new tests, keep Django TestCase for existing
│
├─ API-only (no web framework) → pytest + pytest-mock + httpx (for HTTP calls)
│         Pattern: plain unit tests + httpx for external API testing
│
└─ Non-web (CLI, data processing, library) → pytest + pytest-mock
│         Pattern: standard unit tests with mocking where needed
│         No HTTP client needed
```

### Step 6: E2E / API Testing

```
Does the project expose HTTP endpoints?
├─ YES → Check framework for E2E approach
│         ├─ FastAPI/Flask/Django → Integration tests via test client (not browser E2E)
│         │   FastAPI: httpx.AsyncClient or TestClient
│         │   Flask: app.test_client() or flask.testing.TestClient
│         │   Django: pytest-django + Client or APIClient from REST framework
│         │
│         │   For true browser E2E:
│         │   ├─ Playwright (pytest-playwright) — recommended
│         │   └─ Selenium — only if existing investment
│         │
│         ├─ Has frontend (Jinja templates, HTMX) → pytest-playwright
│         │   Rationale: Browser-level testing for server-rendered pages
│         │
│         └─ API-only (REST/GraphQL) → httpx + pytest for integration tests
│             No browser automation needed — test via HTTP client
│
├─ NO → Skip E2E framework recommendation
│         Non-web Python projects (CLI, libraries, data pipelines) do not
│         need browser or HTTP-level E2E testing.
│
└─ Unknown → Present options, default to httpx integration tests
```

### Step 7: Coverage Provider

```
Determine coverage approach:
├─ pytest → pytest-cov (wraps coverage.py)
│         Install: pytest-cov
│         Run: pytest --cov=src --cov-report=term-missing
│         Config: pyproject.toml [tool.coverage.run] or .coveragerc
│         Branch coverage: --cov-branch flag (recommended)
│
├─ unittest → coverage.py directly
│         Run: coverage run -m unittest discover && coverage report
│         Config: .coveragerc or pyproject.toml [tool.coverage]
│
└─ Default → pytest-cov (covers 99% of Python testing scenarios)
```

## Confidence Thresholds for Recommendations

| Scenario | Confidence | Explanation |
|----------|------------|-------------|
| Existing pytest detected → Keep pytest | 0.95+ | pytest is already optimal |
| Existing unittest, simple → pytest as runner | 0.80+ | Smooth migration path |
| Existing unittest, complex → Keep + pytest runner | 0.85+ | Stability, gradual adoption |
| No existing framework → pytest | 0.95+ | Industry standard for Python |
| FastAPI detected → httpx + pytest-asyncio | 0.90+ | Official FastAPI testing docs |
| Flask detected → pytest + Flask test client | 0.90+ | Flask documentation pattern |
| Django detected → pytest-django | 0.85+ | Best pytest integration for Django |
| Async detected → pytest-asyncio | 0.90+ | Required for correct async testing |
| Frontend detected → pytest-playwright | 0.85+ | Best browser automation for Python |
| API-only → httpx integration tests | 0.85+ | Purpose-built for API testing |

## Decision Summary Table

| Detected Stack | Test Runner | Plugins | Coverage | E2E / Integration | Config File |
|----------------|-------------|---------|----------|-------------------|-------------|
| FastAPI | pytest | pytest-asyncio, httpx | pytest-cov | httpx AsyncClient | `pyproject.toml` |
| Flask | pytest | pytest-flask (optional) | pytest-cov | Flask test_client | `pyproject.toml` |
| Django | pytest | pytest-django | pytest-cov | Django Client / APIClient | `pyproject.toml` |
| Express API (no web framework) | pytest | pytest-mock, httpx | pytest-cov | httpx | `pyproject.toml` |
| CLI / Script | pytest | pytest-mock, pytest-tmp-files | pytest-cov | Subprocess tests | `pyproject.toml` |
| Data / ML | pytest | pytest-mock | pytest-cov | Fixture-based validation | `pyproject.toml` |
| Existing pytest (simple) | pytest (keep) | As-is | pytest-cov | As-is | Existing config |
| Existing pytest (complex) | pytest (keep) | As-is + evaluate gaps | pytest-cov | As-is | Existing config |
| Existing unittest (simple) | pytest (runner) | pytest-mock | pytest-cov | Depends on app type | `pyproject.toml` |
| Existing unittest (complex) | pytest + unittest | pytest-mock | pytest-cov | Depends on app type | `pyproject.toml` |
| Async + FastAPI | pytest | pytest-asyncio, httpx | pytest-cov | httpx AsyncClient | `pyproject.toml` |
| Monorepo (Python) | pytest | Per-module plugins | pytest-cov | Per-module approach | Root `pyproject.toml` + per-module `conftest.py` |

## ADR Template

When the detection engine makes a framework recommendation, document it as an Architecture Decision Record in `.bestest/adrs/`:

```markdown
# ADR-NNN: [Test Framework Selection]

## Status: Proposed

## Context
- **Languages detected**: [from StackProfile.languages]
- **Python version**: [from StackProfile.runtime.python or "unknown"]
- **Web framework**: [from StackProfile.frameworks or "none"]
- **Package manager**: [from StackProfile.packageManager]
- **Existing test framework**: [from StackProfile.testFrameworks.existing or "none"]
- **Async usage**: [detected or "none"]

## Decision
Adopt **pytest** for [unit/integration/E2E] testing with [plugins list].

## Rationale
[Auto-populated from the decision tree path taken. Example:]
"pytest is the industry standard for Python testing. FastAPI detected → httpx
AsyncClient provides the official test client. pytest-asyncio handles async
test functions. pytest-cov wraps coverage.py for coverage collection."

## Consequences
- [Specific benefit from the recommendation]
- [Any trade-off or limitation]
- [Migration effort if changing from existing framework]

## Alternatives Considered
- **unittest**: [Standard library, no install needed, but verbose and less powerful fixtures]
- **nose2**: [Legacy, less active development, fewer plugins than pytest]
```

## Integration with Detection Engine

The Python decision tree is evaluated after the detection engine has populated all signal categories. The evaluation follows this sequence:

1. Build the StackProfile from all detected signals (including Python-specific signals)
2. Determine primary language → if Python, use this decision tree instead of js-ts-decision-tree
3. Evaluate Step 1–7 in order (short-circuit on first match)
4. Populate `testFrameworks.recommended`, `e2eFramework.recommended`, and `coverage.recommended`
5. Generate ADR if the recommendation differs from existing setup
6. Route to the appropriate spoke command (init, generate, fix)

The decision tree is deterministic: the same StackProfile always produces the same recommendation. This ensures reproducibility and makes the recommendation auditable via the ADR.

## Common Plugin Recommendations by Use Case

| Use Case | Plugin | Why |
|----------|--------|-----|
| Mocking | pytest-mock | Thin wrapper around unittest.mock with fixture integration |
| Async testing | pytest-asyncio | Event loop management for async test functions |
| HTTP testing | httpx | Modern HTTP client with async support, replaces requests |
| Environment variables | pytest-env | Set environment variables per test |
| Temporary files | pytest-tmp-files | Enhanced tmp_path fixtures |
| Snapshot testing | syrupy | Snapshot assertion library |
| Type checking in tests | pytest-mypy-plugins | Run mypy checks as tests |
| Random test ordering | pytest-randomly | Detect hidden inter-test dependencies |
| Slow test marking | pytest-timeout | Fail tests that exceed time limit |
| Benchmarking | pytest-benchmark | Performance regression detection |
| Django | pytest-django | Django integration (fixtures, DB, settings) |
| Flask | pytest-flask | Flask application fixtures |
| Playwright E2E | pytest-playwright | Browser automation via Playwright |
| Coverage | pytest-cov | Coverage.py integration |
| Parallel execution | pytest-xdist | Distribute tests across CPUs |
