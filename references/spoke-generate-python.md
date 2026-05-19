# /bestest generate (Python)

## Purpose

AI-powered pytest test generation spoke implementing the full 7-phase pipeline for Python projects. Generates production-quality tests for target source files, ensuring every generated test compiles (via `py_compile`), passes (via `pytest`), covers meaningful behavior, and scores ≥ `quality_threshold` (default 0.7) on the assertion quality audit rubric from `references/python-generation-guide.md`. Supports targeting specific files, untested modules, code type filtering, and critical-path prioritization.

The generate spoke is the primary value delivery command — it transforms scan insights into concrete test files. Every test it produces must be a net positive: compiling, passing, contributing real coverage, and free of the anti-patterns cataloged in `references/anti-patterns.md` and the Python-specific anti-patterns in `references/python-generation-guide.md`.

## Prerequisites

- `.bestest/` directory with valid `config.yaml` where `language: python` and `framework: pytest` (run `/bestest init` first)
- StackProfile at `.bestest/state/stack-profile.json` for framework-appropriate generation patterns
- Scan report with `gaps[]` and `testInventory[]` arrays (run `/bestest scan` first for optimal targeting)
- Scan report is not strictly required — the spoke can generate in degraded mode without it, using filesystem scanning instead of gap targeting
- Python virtual environment detected (one of: `VIRTUAL_ENV` env var, `.venv/` directory, Poetry environment, Conda environment)

> **Shared pipeline:** This spoke implements the 7-phase generation pipeline. Shared sections (Parallel Dispatch Decision, Priority Scoring Formula, Default Targeting, Pre-read Instruction, Content Boundary Notice, Taint Notice, HITL Gate, Error Handling stub, Config State Update, Downstream Reference) are defined in `references/generate/pipeline-shared.md`. Only language-specific phases and deltas are documented below.

## Pre-Flight Checks

Run these checks before starting any generation work. They validate the environment, configuration, and data sources needed for the 7-phase pipeline.

> See **references/pre-flight-protocol.md** for the standard 3-step `.bestest/` validation pattern and spoke-specific variants.

### 1. Check for `.bestest/` with valid config

```
If .bestest/ does not exist or config.yaml is missing/invalid:
  Print appropriate error with guidance (run /bestest init).
  Exit.
```

Parse `generation.*` fields from config (see `references/config-schema.md` for full schema):

| Field | Type | Default | Usage |
|-------|------|---------|-------|
| `generation.quality_threshold` | number | `0.7` | Minimum quality score (0–1 scale). Tests scoring below this are flagged for improvement. |
| `generation.verify_compilation` | boolean | `true` | Whether Phase 5 (compilation check) runs. Skip to speed up generation at the cost of import/syntax safety. |
| `generation.verify_pass` | boolean | `true` | Whether Phase 6 (execution check) runs. Skip to generate without running tests. |
| `generation.max_retries` | number | `2` | Maximum fix-and-rerun attempts in Phase 6 when generated tests fail. |
| `generation.parallel.enabled` | boolean | `true` | Allow parallel dispatch when target count meets threshold. Set `false` to force sequential processing. |
| `generation.parallel.min_targets` | number | `5` | Minimum source files to trigger parallel mode. Below this, always sequential. |
| `generation.parallel.group_size` | number | `5` | Max source files per worker when dispatching in parallel. |
| `generation.parallel.depth_limit` | number | `1` | Max dispatch recursion depth (always 1 — workers never spawn workers). |

Verify that `config.yaml` has `framework: pytest` and `language: python`. If `framework` is something else (vitest, jest), route to the appropriate generation spoke instead.

### 2. Check for Python environment

```
Check for virtual environment, then verify pytest is installed.
If no virtual environment: print warning, continue in degraded mode (Phase 5/6 may fail).
If pytest not installed: print install guidance, exit.
Check for pytest plugins (pytest-asyncio, pytest-mock, pytest-cov, httpx, pytest-django).
  Note missing plugins but do not block generation — only skip tests requiring the plugin.
```

> **On-demand load:** For detailed virtual environment detection algorithm (venv, Poetry, Conda, Pipenv), pytest plugin detection list, and degraded-mode behavior, read `references/generate/python/phase1-target-detail.md`.

### 3. Check for StackProfile

Reference: `references/stack-profile-schema.md` for the full JSON shape.

```
If .bestest/state/stack-profile.json does not exist:
  Print: "Warning: StackProfile not found. Will attempt framework detection from pyproject.toml and imports."
  Set framework = detect from pyproject.toml dependencies and source imports
  If framework cannot be detected:
    Set framework = "generic"
Else:
  Read and parse StackProfile JSON.
  If JSON parsing fails → see state corruption handling in references/generate/python/phase1-target-detail.md.
  Extract testFrameworks.existing → confirm it matches "pytest".
  Extract coverage.provider → determines coverage commands (pytest-cov).
  Extract web framework → determines test client pattern (FastAPI, Flask, Django).
  Extract languages → confirms Python is primary.
  Extract async usage → determines pytest-asyncio need.
```

### 4. Confidence Gate

Confidence gate: See SKILL.md "Confidence Gate (R5)" — the orchestrator checks confidence before loading this spoke. If you reached this spoke, confidence already passed the gate.

### 5. Check for scan report

```
If no scan report exists in .bestest/reports/:
  Print: "Warning: No scan report found. Generation will use filesystem scanning."
  Set mode = "filesystem-scan", gaps = [], testInventory = [].
Else:
  Load most recent scan report. Extract gaps[], testInventory[], configSnapshot.
  Set mode = "scan-guided".
```

### 6. Validate artifact schemaVersions

```
Validate stack-profile.json schemaVersion ≤ 1.3 and scan-report.json schemaVersion ≤ 1.2.
If MAJOR version differs → error and exit.
If MINOR exceeds expected → warning and continue.
If missing → treat as "1.0" legacy. Continue.
See references/generate/python/phase1-target-detail.md for full validation algorithm.
```

---

## Phase 1 — Target Selection

Determine which source files to generate tests for. Four targeting modes operate with priority ordering: explicit path overrides all other modes. Target file patterns for Python: `**/*.py` excluding `test_*.py`, `*_test.py`, `conftest.py`, `__init__.py`, and files in `migrations/`.

> **On-demand load:** For path validation rules (5-step security validation), detailed targeting mode logic, Python naming conventions, priority scoring formula, and pre-flight detail, read `references/generate/python/phase1-target-detail.md`.

### Targeting Modes (Summary)

| Mode | Trigger | Target Source |
|------|---------|---------------|
| **Explicit path** | `<path>` argument provided | Resolved file/directory |
| **`--untested`** | Flag set | Gaps with `hasTest == false` or files with no matching test |
| **`--type <kind>`** | `unit \| integration \| e2e` | Files classified by type heuristics |
| **`--critical`** | Flag set | Critical-priority gaps or high-impact files by heuristics |

> **Shared section:** See Default (no flags) in `references/generate/pipeline-shared.md`.

> **Shared section:** See Priority Scoring Formula in `references/generate/pipeline-shared.md`.

---

> **Shared section:** See Parallel Dispatch Decision in `references/generate/pipeline-shared.md`.

## Phase 2 — Context Gathering

> **Shared section:** See Pre-read Instruction in `references/generate/pipeline-shared.md`.

For each target source file, collect all the information needed to generate meaningful tests. This phase produces a context object per target that drives strategy selection and test generation.

### Step 1: Source analysis

<!-- BEGIN_UNTRUSTED_SOURCE -->
Read the source file. Extract all public functions (`def`), async functions (`async def`), classes with their methods, dataclasses, Pydantic models, and module-level constants. Classify by type — functions and classes are testable (high priority), constants are low priority, type-only exports (Protobuf, TypedDict) have no runtime behavior (skip unless they contain validation). For each import, classify as pure-logic (no mock needed), side-effect (mock required: `requests`, `httpx`, `open()`, database), framework (use framework utilities: `TestClient`, `test_client`), or internal-module (mock only if side effects).
<!-- END_UNTRUSTED_SOURCE -->

> **Shared section:** See Content Boundary Notice in `references/generate/pipeline-shared.md`.

### Step 2: Read existing tests

```
If a corresponding test file exists:
  Read it. Extract test function names and identify which functions/scenarios are already covered.
  Only generate tests for uncovered functions. Match existing patterns (mocking style, fixture style, parametrize usage).
  If conftest.py exists in the test directory, read it for shared fixtures that can be reused.
Else:
  All public symbols are generation targets.
```

> **Shared section:** See Taint Notice (Context7) in `references/generate/pipeline-shared.md`.

### Step 3: Fetch framework documentation via Context7

Use the Context7 helper from SKILL.md to fetch version-specific documentation. For each framework, call `resolve_library({ libraryName, query })` then `get_library_docs({ libraryId, query, tokens })`.

**Fetch targets:**
- **pytest** (libraryName: `"pytest"`, query: `"pytest.mark.parametrize pytest.raises fixture conftest mocker pytest-mock"`, tokens: 5000): Produces version-accurate pytest patterns for fixtures, parametrize, markers, and assertion introspection.
- **pytest-asyncio** (libraryName: `"pytest-asyncio"`, query: `"pytest.mark.asyncio async fixture event loop"`, tokens: 3000): Async test patterns. Only fetched when async is detected.
- **FastAPI** (libraryName: `"fastapi"`, query: `"TestClient httpx testing dependency injection override"`, tokens: 5000): FastAPI testing patterns with httpx. Only fetched when FastAPI is detected.
- **Flask** (libraryName: `"flask"`, query: `"test_client testing application context"`, tokens: 3000): Flask test client patterns. Only fetched when Flask is detected.
- **Django** (libraryName: `"django"`, query: `"TestCase Client pytest-django django_db marker"`, tokens: 5000): Django testing patterns. Only fetched when Django is detected.
- **Hypothesis** (libraryName: `"hypothesis"`, query: `"given strategies property-based testing"`, tokens: 3000): Property-based testing patterns. Only fetched when complexity warrants it.

> **Shared section:** See Graceful Fallback (Context7) in `references/generate/pipeline-shared.md`. For Python, the static fallback source is `references/python-generation-guide.md`.

### Step 4: Dependency identification

For each side-effect dependency: Network calls → `mocker.patch("module.httpx")` or `mocker.patch("module.requests")`. Filesystem → `mocker.patch("builtins.open")` or use `tmp_path` fixture. Database → mock at the ORM/client module. Timers → `mocker.patch("time.time")` or `freezegun` fixture. Random → `mocker.patch("random.random")`. Environment → `mocker.patch.dict(os.environ, {...})`. Internal modules with side effects → `mocker.patch("package.module.dependency")`.

**Critical rule:** Always patch where the function is *used*, not where it is *defined*. For example, if `src/service.py` does `from utils import db_query`, patch `src.service.db_query`, not `utils.db_query`.

### Step 5: Complexity estimation

Estimate cyclomatic complexity by counting branching (`if`, `elif`, ternary, `and`, `or`), loops (`for`, `while`, comprehensions), exception handling (`try/except`, `raise`), and early returns. Map to test count: complexity 1-3 → 2-3 tests, 4-8 → 4-6, 9-15 → 6-10, 16+ → 10+ (consider suggesting source refactoring).

### Step 6: Check for conftest.py fixtures

```
If conftest.py files exist in the test directory tree:
  Read them to discover shared fixtures.
  Categorize fixtures by purpose:
    - Data factories (create_user, create_item) → reuse in generated tests
    - Client fixtures (client, api_client) → reuse for route testing
    - Database fixtures (db_session, test_db) → reuse for ORM testing
    - Mock fixtures (mock_external_api) → reuse for integration testing
  If a suitable fixture already exists, reference it instead of creating a new one.
  If no suitable fixture exists, generate one in the test file (not in conftest.py).
```

---

## Phase 3 — Test Strategy Selection

Map each target symbol to a test strategy using the code type heuristics from `references/python-generation-guide.md`. The strategy determines test structure, assertion style, and required utilities.

### Code Type → Strategy Mapping

| Code Type | Detection Heuristics | Strategy | Test Structure |
|-----------|---------------------|----------|----------------|
| **Pure function** | No side-effect imports, returns computed value | Input/output assertions with boundary values | `@pytest.mark.parametrize` with equivalence classes |
| **Class / methods** | `class` keyword, `self` parameter, methods | Constructor + method tests with instance isolation | Fixture for fresh instance per test |
| **Async function** | `async def`, `await` keyword | Proper async/await with `@pytest.mark.asyncio` | Mock async boundary, test all coroutine states |
| **FastAPI route** | Imports from `fastapi`, `APIRouter`, `@app.get/post` | Request/response via `httpx.AsyncClient` | Fixture that yields client with dependency overrides |
| **Flask route** | Imports from `flask`, `@app.route` | Request/response via `app.test_client()` | Fixture with `TESTING=True` and `app_context` |
| **Django view** | Imports from `django`, view functions, class-based views | Request/response via `django.test.Client` | `@pytest.mark.django_db` + factory fixtures |
| **Data model / Pydantic** | `BaseModel`, `dataclass`, field validators | Validation and serialization tests | `@pytest.mark.parametrize` for validation matrix |
| **Generator / iterator** | `yield` in function body, `__iter__` | Iteration protocol assertions | Direct `next()` calls and `StopIteration` |
| **CLI command** | `argparse`, `click`, `sys.argv` | Subprocess or isolated invocation | `mocker.patch("sys.argv")` or CliRunner |
| **ORM / database** | SQLAlchemy models, Django models, migration operations | Database session with rollback | Transactional fixture with isolated session |

### Strategy selection per export

```
For each public symbol in the target source file:
  1. Check import list for framework indicators (FastAPI, Flask, Django, Click)
  2. Check function signature (async def → async, self → class method, cls → classmethod)
  3. Check return type annotation (BaseModel → data model, Response → API route, Generator → generator)
  4. Check decorators (@app.route, @router.get, @dataclass, @field_validator)
  5. Check for side-effect dependencies (determined in Phase 2 Step 4)
  6. Assign the matching strategy from the table above.
  7. Record required test utilities and markers (@pytest.mark.asyncio, @pytest.mark.django_db).
```

### What to assert per strategy

- **Pure function:** Specific return values for each input class. Edge cases at boundaries. Error handling for invalid inputs using `pytest.raises`.
- **Class / methods:** Constructor sets correct attributes. Public methods return expected values. Properties compute correctly. State transitions are isolated.
- **Async function:** Successful resolution with expected data. Error handling (network failure, timeout, invalid response). Cleanup on cancellation. Race condition handling if applicable.
- **FastAPI route:** Status codes (200, 201, 400, 401, 404, 422, 500). Response body shape. Validation error format. Authentication/authorization checks. Dependency override behavior.
- **Flask route:** Status codes (200, 201, 400, 404, 500). Response body content. Redirect behavior. Session state changes. Error handler responses.
- **Django view:** Status codes. Template context. ORM changes (created/updated/deleted records). Permission checks. Form validation errors.
- **Data model:** Field validation passes for valid data. Field validation rejects invalid data. Default values applied correctly. Serialization/deserialization round-trips.

---

## Phase 4 — Test Generation

Generate test files using pytest-specific syntax. Every generated test follows the Arrange-Act-Assert pattern and targets meaningful behavior, not implementation details.

### pytest test file header

```python
import pytest
from unittest.mock import MagicMock, patch

from module import function_under_test
```

When `pytest-mock` is available (detected from installed plugins), use the `mocker` fixture instead of raw `unittest.mock`:

```python
import pytest

from module import function_under_test
```

### Test naming convention

Every test name describes the specific scenario and expected outcome. Follow the pattern: `test_{unit}_{behavior}_when_{condition}`.

```
Good examples:
  def test_calculate_discount_returns_reduced_price_when_percentage_is_valid():
  def test_fetch_user_raises_connection_error_when_fetch_returns_503():

Bad examples (never generate these):
  def test_works():
  def test_handles_error():
  def test_1():
```

> **On-demand load:** For complete mocking patterns (pytest-mock, unittest.mock, async, env vars, FastAPI dependency override), factory functions, parametrize patterns, and the full well-generated test file example, read `references/generate/python/phase4-generation-detail.md`.

### Generation rules

1. **Arrange-Act-Assert in every test.** Separate sections with blank lines. Never combine act and assert.
2. **Error path tests alongside happy paths.** Every function that can raise or return errors gets error path tests using `pytest.raises`.
3. **No test for import-only modules.** Skip `__init__.py` files that only re-export symbols.
4. **Factory functions for all test data.** No hardcoded dicts repeated across tests.
5. **Mock at boundaries only.** External services (network, filesystem, database), never internal utility functions.
6. **Specific assertions.** Use `==` for exact values, `pytest.approx` for floats. Avoid bare `assert result` on non-boolean values.
7. **Proper cleanup.** Fixtures with `yield` clean up resources. `mocker` auto-resets. No leaked state between tests.
8. **Async markers required.** Every `async def test_*` function must have `@pytest.mark.asyncio` (unless `asyncio_mode = "auto"` is configured).
9. **Django DB markers required.** Every test accessing the ORM must have `@pytest.mark.django_db`.
10. **Patch where used, not defined.** `mocker.patch("module_where_used.function_name")` not `mocker.patch("module_where_defined.function_name")`.

---

## Phase 5 — Compilation Verification

> **Iteration budget:** Before each Phase 5 execution, decrement the global iteration budget per the Global Iteration Budget section in `references/generate/pipeline-shared.md`. If the budget is exhausted, halt and present the diagnostic summary.

> **On-demand load:** When compilation verification is needed, read `references/generate/python/phase5-compilation.md`. Apply the auto-fix patterns and retry loop defined there.

---

## Phase 6 — Execution Verification

> **Iteration budget:** Before each Phase 6 execution, decrement the global iteration budget per the Global Iteration Budget section in `references/generate/pipeline-shared.md`. If the budget is exhausted, halt and present the diagnostic summary.

> **On-demand load:** When execution verification is needed, read `references/generate/python/phase6-execution.md`. Run tests, analyze failures, and apply the fix-and-rerun loop defined there.

---

## Phase 7 — Quality Audit

> **On-demand load:** When quality audit scoring, anti-pattern detection, or flakiness testing is needed, read `references/generate/python/phase7-quality-audit.md`. Apply the scoring rubric, anti-pattern checks, and flakiness testing defined there.

---

## HITL Gate

> **Shared section:** See HITL Gate Core in `references/generate/pipeline-shared.md`.

---

## Output

After successful completion, the following artifacts exist:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Generated test files | Configured test directory (per `pytest.testpaths`) | Test files matching naming convention (e.g., `test_calculate.py`) |
| Updated conftest.py | Test directory (if new shared fixtures needed) | Shared fixtures for generated tests |
| Updated reports | `.bestest/reports/` | Coverage metrics and quality scores |
| Updated TESTING.md | Repo root | New test inventory reflecting generated tests |
| Updated config state | `.bestest/config.yaml` | `state.last_generate` timestamp updated |

### Test file placement

| Source File | Generated Test File |
|-------------|-------------------|
| `src/utils/calculate.py` | `tests/test_calculate.py` or `tests/utils/test_calculate.py` |
| `src/api/users.py` | `tests/test_users.py` or `tests/api/test_users.py` |
| `app/services/cart.py` | `tests/test_cart.py` or `tests/services/test_cart.py` |

> **Shared section:** See Config State Update in `references/generate/pipeline-shared.md`.

---

> **Shared section:** See Error Handling Stub Pattern in `references/generate/pipeline-shared.md`. For Python, error handling detail is at `references/generate/python/error-handling.md`.

---

## Metrics Update

This spoke writes to `.bestest/state/metrics.json` following the shared metrics-update protocol defined in `references/metrics-schema.md`.

Before reading metrics.json, acquire the concurrency lock per `references/pre-flight-protocol.md` → Concurrency Lock Protocol. The lock must be held for the entire read-modify-write cycle (Steps 0–8). If the lock cannot be acquired, log a warning and proceed with a best-effort write.

### Sections Updated

`tests`, `activity`

### Field Mapping

| Field | Source | Update Rule |
|-------|--------|-------------|
| `tests.*` | All test counts from run results | Replace with current value |
| `activity[]` | Current spoke invocation metadata | Append entry, evict oldest if over maxLength |

### Update Protocol

Follow this protocol on every invocation:

```
0. Acquire lock on .bestest/state/.metrics.lock
   - Use flock with 5-second timeout (primary) or mkdir-based fallback
   - If lock cannot be acquired, proceed anyway with a warning (best-effort)
   - For the full lock acquisition and release protocol, see references/pre-flight-protocol.md → Concurrency Lock Protocol
1. Read .bestest/state/metrics.json
2. Parse as JSON
3. If parse fails (corruption):
   a. Log warning: "metrics.json corrupted — recreating with defaults"
   b. Initialize fresh metrics with schemaVersion "1.0" and default values
   c. Continue with step 5 (do NOT abort the spoke)
4. Validate schemaVersion — warn if MAJOR differs, proceed if MINOR differs
5. Merge spoke-specific data:
   - Update lastUpdated to current ISO 8601 timestamp
   - Update only this spoke's sections (listed above), leave others unchanged
   - Append to bounded arrays (history, trend, activity), evicting oldest when over maxLength
   - Recalculate derived values (healthScore, overallFlakeRate, etc.)
6. Write back to .bestest/state/metrics.json (atomic write: write to temp file, then rename)
7. Update config.yaml state.last_metrics with current timestamp
8. Release lock on .bestest/state/.metrics.lock
   - flock: released automatically when the subshell/process exits
   - mkdir: remove the lock directory with rm -rf
```

### Activity Log Entry

Append an entry to the `activity` array:

```json
{
  "timestamp": "<current ISO 8601>",
  "spoke": "spoke-generate-python",
  "action": "generate",
  "summary": "<human-readable one-line summary>"
}
```

### Graceful Degradation

- **File missing:** Treated as first-time creation. Write this spoke's section with defaults for all others.
- **Parse failure:** Log warning, recreate with defaults + current spoke's data. **Never abort the spoke** — metrics are observability, not a gate.
- **schemaVersion mismatch (MAJOR):** Log warning, attempt to read known fields, write back with current schema version.
- **schemaVersion mismatch (MINOR):** Proceed normally. Unrecognized fields are preserved (pass-through).



## Downstream Reference

> **Shared section:** See Downstream Reference Core in `references/generate/pipeline-shared.md`. Python additionally supports `/bestest run` (execute the full test suite with unified result capture).
