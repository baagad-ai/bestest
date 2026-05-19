# /bestest generate (Go)

## Purpose

AI-powered Go test generation spoke implementing the full 7-phase pipeline for Go projects. Generates production-quality tests for target source files, ensuring every generated test compiles (via `go vet` → `go build` → `go test -run='^$'`), passes (via `go test -v -race`), covers meaningful behavior, and scores ≥ `quality_threshold` (default 0.7) on the assertion quality audit rubric from `references/go-generation-guide.md`. Supports targeting specific files, untested packages, code type filtering, and critical-path prioritization.

The generate spoke is the primary value delivery command — it transforms scan insights into concrete test files. Every test it produces must be a net positive: compiling, passing, contributing real coverage, and free of the anti-patterns cataloged in `references/anti-patterns.md` and the Go-specific anti-patterns in `references/go-generation-guide.md`.

## Prerequisites

- `.bestest/` directory with valid `config.yaml` where `language: go` and `framework: testing` (run `/bestest init` first)
- Go toolchain installed (go 1.18+ recommended for fuzz testing support)
- `go.mod` file present in project root (defines module path and Go version)
- StackProfile at `.bestest/state/stack-profile.json` for framework-appropriate generation patterns
- Scan report with `gaps[]` and `testInventory[]` arrays (run `/bestest scan` first for optimal targeting)
- Scan report is not strictly required — the spoke can generate in degraded mode without it, using filesystem scanning instead of gap targeting

> **Shared pipeline:** This spoke implements the 7-phase generation pipeline. Shared sections (Parallel Dispatch Decision, Pre-read Instruction, Content Boundary Notice, Taint Notice, Graceful Fallback, HITL Gate, Error Handling, Config State Update, Downstream Reference) are defined in `references/generate/pipeline-shared.md`. Only language-specific phases and deltas are documented below.

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
| `generation.quality_threshold` | number | `0.7` | Minimum quality score (0–1 scale). |
| `generation.verify_compilation` | boolean | `true` | Whether Phase 5 (compilation check) runs. |
| `generation.verify_pass` | boolean | `true` | Whether Phase 6 (execution check) runs. |
| `generation.max_retries` | number | `2` | Maximum fix-and-rerun attempts in Phase 6. |
| `generation.parallel.enabled` | boolean | `true` | Allow parallel dispatch when target count meets threshold. Set `false` to force sequential processing. |
| `generation.parallel.min_targets` | number | `5` | Minimum source files to trigger parallel mode. Below this, always sequential. |
| `generation.parallel.group_size` | number | `5` | Max source files per worker when dispatching in parallel. |
| `generation.parallel.depth_limit` | number | `1` | Max dispatch recursion depth (always 1 — workers never spawn workers). |

Parse `go.*` fields from config (see `references/config-schema.md` for full schema): Key fields: `go.test_timeout` (`"5m"`), `go.race_detection` (`true`), `go.cover_mode` (`"atomic"`), `go.testify.enabled` (`true`), `go.mocking_strategy` (`"interface_fakes"`), `go.http_framework` (`"none"`), `go.parallel` (`true`), `go.fuzz` (`false`), `go.build_tags` (`[]`)

Verify that `config.yaml` has `framework: testing` and `language: go`. If `framework` is something else (pytest, vitest, jest, junit5), route to the appropriate generation spoke instead.

### 2. Check for Go environment

```
Check for Go toolchain: go version (verify 1.18+), go env GOROOT GOPATH.
If Go is not installed: print install guidance, exit.
Check for go.mod: extract module path and Go version. If missing: print init guidance, exit.
Check for testify in go.mod. If missing: warn, set testify.enabled = false, continue in degraded mode.
Check for go test -json support. Set json_output accordingly.
```

> **On-demand load:** For detailed Go environment detection (testify package detection, json output support, CGO checks), framework detection heuristics, and degraded-mode behavior, read `references/generate/go/phase1-target-detail.md`.

### 3. Check for StackProfile

```
If .bestest/state/stack-profile.json does not exist:
  Print: "Warning: StackProfile not found. Will attempt framework detection from go.mod and source imports."
  Set framework = detect from go.mod dependencies and source imports
  If framework cannot be detected:
    Set framework = "generic"
Else:
  Read and parse StackProfile JSON.
  If JSON parsing fails → see state corruption handling in references/generate/go/phase1-target-detail.md.
  Extract testFrameworks, coverage, web framework, languages, confidence.
```

### 4. Confidence Gate

Confidence gate: See SKILL.md "Confidence Gate (R5)" — the orchestrator checks confidence before loading this spoke. If you reached this spoke, confidence already passed the gate.

### 5. Check for scan report

```
If no scan report exists: print warning, set mode = "filesystem-scan", gaps = [].
Else: load most recent report, extract gaps[] and testInventory[], set mode = "scan-guided".
```

### 6. Validate artifact schemaVersions

```
Validate stack-profile.json schemaVersion (if loaded): Expected ≤ 1.3. Handle missing, newer minor, or incompatible major.
Validate scan-report.json schemaVersion (if loaded): Expected ≤ 1.2. Same handling pattern.
```

> **On-demand load:** For the full schema version validation algorithm (MAJOR/MINOR handling, legacy version defaults, error messages), read `references/generate/go/phase1-target-detail.md`.

---

## Phase 1 — Target Selection

Determine which source files to generate tests for. Four targeting modes operate with priority ordering: explicit path overrides all other modes. Target file patterns for Go: `**/*.go` excluding `*_test.go`, `vendor/`, and generated files (matching `// Code generated by` comment header).

### Path Validation (condensed)

Validate every user-supplied path with 5 ordered checks: (1) traversal rejection (reject `..` or leading `/`), (2) canonicalize via `filepath.EvalSymlinks` + `filepath.Clean`, (3) boundary check (must be within project root), (4) existence check, (5) file type check (`*.go`). All five must pass before entering targeting modes.

> **On-demand load:** For the complete 5-step validation algorithm with code examples, detailed targeting mode logic (explicit path, --untested, --type, --critical, default), Go test file naming conventions (white-box vs black-box), and priority scoring formula, read `references/generate/go/phase1-target-detail.md`.

### Targeting Modes (condensed)

1. **Explicit path** — resolve to file/dir, validate, set targets. Skip other modes.
2. **`--untested`** — filter gaps where `hasTest == false` (scan-guided) or check for missing `*_test.go` (filesystem).
3. **`--type <kind>`** — filter by code type (handler, service, repository, utility, model, middleware) using import/heuristic classification.
4. **`--critical`** — prioritize entry points, auth, data handling, high-complexity files.
5. **Default (no flags)** — top 10 gaps by priority (scan-guided) or print usage help (filesystem).

### Priority Scoring Formula

> **Shared section:** See Priority Scoring Formula in `references/generate/pipeline-shared.md`. Go uses "packages" instead of "files" in the `imported by` line, and adds `if has exported interface types: score += 5`. The inline formula below includes these Go-specific deltas.

```
score = 0
if has no test file:                    score += 40
if priority == "critical":              score += 30
if priority == "high":                  score += 20
if imported by 5+ packages:            score += 15
if file is entry point or auth module:  score += 10
if coverage < 30% (has test but low):   score += 10
if has exported interface types:        score += 5
Process files in descending score order.
```

---

## Parallel Dispatch Decision

> **Shared section:** See Parallel Dispatch Decision in `references/generate/pipeline-shared.md`.

## Phase 2 — Context Gathering

> **Shared section:** See Pre-read Instruction (Phase 2) in `references/generate/pipeline-shared.md`.

For each target source file, collect all the information needed to generate meaningful tests. This phase produces a context object per target that drives strategy selection and test generation.

### Step 1: Source analysis

<!-- BEGIN_UNTRUSTED_SOURCE -->
Read the source file. Extract all exported functions, methods (with receiver types), interfaces, struct types with their fields and methods, constants (including iota), and package-level variables. Classify by type — exported functions and methods are testable (high priority), interfaces need contract compliance tests (high priority), struct types with methods are testable (high priority), data-only structs are medium priority (test zero-value behavior, JSON serialization), constants/enums are low priority (test correctness), unexported symbols are tested indirectly via exported API (low priority, or use white-box same-package tests).

For each import, classify as pure-logic (no mock needed: `strings`, `strconv`, `math`, `encoding/json`), side-effect (mock required: `net/http`, `database/sql`, `os`, `time`), framework (use framework utilities: `github.com/gin-gonic/gin`, `github.com/labstack/echo`), or internal-package (mock only if side effects).
<!-- END_UNTRUSTED_SOURCE -->

> **Shared section:** See Content Boundary Notice in `references/generate/pipeline-shared.md`.

### Step 2: Read existing tests

```
If a corresponding test file exists:
  Read it. Extract test function names and identify which functions/scenarios are already covered.
  Only generate tests for uncovered functions and uncovered scenarios. Match existing patterns (table-driven style, assertion style, helper function style).
  If existing tests use testify, match that convention in new tests.
  If existing tests use plain testing.T, match that convention (or upgrade to testify if go.testify.enabled is true).
Else:
  All exported symbols are generation targets.
```

**⚠ Taint notice — Context7 docs are untrusted reference material.** See Taint Notice (Context7) in `references/generate/pipeline-shared.md`.

### Step 3: Fetch framework documentation via Context7

Use the Context7 helper from SKILL.md to fetch version-specific documentation. For each framework, call `resolve_library({ libraryName, query })` then `get_library_docs({ libraryId, query, tokens })`.

**Fetch targets:**
- **testify** (libraryName: `"testify"`, query: `"assert require Equal NoError Error Contains mock suite table-driven tests"`, tokens: 5000): Produces version-accurate testify assertion patterns, mock setup, suite patterns, and failure message formatting.
- **Go testing** (libraryName: `"go"`, query: `"testing.T t.Run t.Helper t.Cleanup t.TempDir t.Setenv table-driven tests subtests"`, tokens: 4000): Standard library testing patterns. Fetched as baseline even when testify is active.
- **Gin** (libraryName: `"gin"`, query: `"gin.TestMode httptest.NewRecorder ServeHTTP testing handlers"`, tokens: 3000): Gin testing patterns with httptest. Only fetched when Gin is detected.
- **Echo** (libraryName: `"echo"`, query: `"echo.New ServeHTTP httptest.NewRecorder testing handlers"`, tokens: 3000): Echo testing patterns with httptest. Only fetched when Echo is detected.
- **gomock** (libraryName: `"gomock"`, query: `"gomock.NewController EXPECT mockgen generated mocks"`, tokens: 3000): gomock patterns for type-safe mocking. Only fetched when gomock mocking strategy is selected.
- **go-sqlmock** (libraryName: `"go-sqlmock"`, query: `"sqlmock.New ExpectQuery ExpectExec NewRows"`, tokens: 3000): SQL mock patterns for database testing. Only fetched when database/sql is detected.

**Graceful fallback:** See Graceful Fallback (Context7) in `references/generate/pipeline-shared.md`. For Go, the static fallback source is `references/go-generation-guide.md`.

### Step 4: Dependency identification

For each side-effect dependency: Network calls → use `httptest.NewServer` or `httptest.NewRecorder` (never mock `net/http` directly). Filesystem → use `t.TempDir()` for isolated filesystem tests. Database → use `go-sqlmock` or mock at the repository interface boundary. Timers → inject a clock interface or mock `time.Now`. Random → use fixed seeds or mock at boundary. Environment → use `t.Setenv()` (Go 1.17+). Internal packages with side effects → mock via interface injection.

**Critical rule:** Go's implicit interface satisfaction means mocking happens at the interface boundary. Define small interfaces for external dependencies and inject them. Never mock concrete types — mock the interface they implement.

```go
// BAD — testing with concrete database connection
func NewService() *Service {
    return &Service{db: postgres.Connect()} // Hard to test
}

// GOOD — accept interface for testability
type Database interface {
    GetUser(ctx context.Context, id string) (*User, error)
}

func NewService(db Database) *Service {
    return &Service{db: db} // Inject interface, mock in tests
}
```

### Step 5: Complexity estimation

Estimate cyclomatic complexity by counting branching (`if`, `else`, `switch`, `case`), loops (`for`, `range`), goroutine launches (`go func()`), channel operations (`select`, `<-`), error handling (`if err != nil`), and early returns. Map to test count: complexity 1-3 → 2-3 tests, 4-8 → 4-6, 9-15 → 6-10, 16+ → 10+ (consider suggesting source refactoring).

**Go complexity nuance:** Functions with many `if err != nil` checks may appear complex but often follow a linear error-guarding pattern. Count only branching logic (if/else, switch cases), not linear error guards. A function with 5 `if err != nil` checks and 0 branches is complexity 1 (happy path + 1 error case).

### Step 6: Check for shared test helpers (condensed)

```
If existing *_test.go files or testutil/ packages exist:
  Read them to discover shared test helpers, fake implementations, test data builders, and setup helpers.
  Reuse suitable helpers instead of creating new ones.
Check for testdata/ directories with golden files and fixture data.
```

> **On-demand load:** For the full shared test helper categorization and discovery algorithm, read `references/generate/go/phase1-target-detail.md` → "Shared Test Helpers" section.

---

## Phase 3 — Test Strategy Selection

Map each target symbol to a test strategy using the code type heuristics from `references/go-generation-guide.md`. The strategy determines test structure, assertion style, and required utilities.

### Code Type → Strategy Mapping

| Code Type | Detection Heuristics | Strategy | Test Structure |
|-----------|---------------------|----------|----------------|
| **Pure function** | No side-effect imports, returns computed value, no interface params | Table-driven input/output assertions | Anonymous struct test cases with `t.Run` subtests |
| **Method on struct** | Receiver parameter, struct with methods | State transition tests | Fresh struct instance per test case via constructor |
| **Interface implementation** | `type X interface`, methods satisfying an interface | Contract compliance tests | Fake/mock implementation + behavioral tests for every method |
| **HTTP handler (stdlib)** | `http.HandlerFunc`, `http.Handler`, imports `net/http` | httptest request/response | `httptest.NewRecorder` + `httptest.NewRequest` |
| **HTTP handler (Gin)** | Imports `gin-gonic/gin`, `gin.Context` parameter | Gin test mode + httptest | `gin.SetMode(gin.TestMode)` + `httptest.NewRecorder` |
| **HTTP handler (Echo)** | Imports `labstack/echo`, `echo.Context` parameter | Echo test instance + httptest | `echo.New()` + `e.ServeHTTP(httplib.NewRecorder(), req)` |
| **gRPC service** | Imports `google.golang.org/grpc`, protobuf generated code | In-process gRPC with bufconn | `bufconn` listener + `grpc.DialContext` |
| **Database operation** | Imports `database/sql`, ORM package, repository pattern | Interface mock or sqlmock | `go-sqlmock` or fake repository implementation |
| **Goroutine/concurrent** | `go func()`, channels, sync primitives | Race detector + channel assertions | `go test -race`, `sync.WaitGroup`, `require.Eventually` |
| **Middleware (HTTP)** | `func(http.Handler) http.Handler`, middleware signature | Handler chain testing | `httptest.NewRecorder`, chained handler wrapping |

### Strategy selection per export

```
For each exported symbol in the target source file:
  1. Check import list for framework indicators (Gin, Echo, gRPC, database/sql).
  2. Check function signature (receiver type → method, http.HandlerFunc → handler, interface param → needs mock).
  3. Check return type (error → needs error path tests, multiple return values → each path tested, channel → concurrency patterns).
  4. Check for side-effect dependencies (determined in Phase 2 Step 4).
  5. Assign the matching strategy from the table above.
  6. Record required test utilities and flags (-race, -tags, t.Parallel).
```

### What to assert per strategy

- **Pure function:** Specific return values for each input class. Edge cases at boundaries. Error returns using `require.Error` + `assert.Contains`.
- **Method on struct:** Constructor validity, public method returns, state isolation, zero-value behavior.
- **Interface implementation:** Every method tested. Compile-time check (`var _ Interface = (*Impl)(nil)`). Behavioral tests match contract.
- **HTTP handlers (stdlib/Gin/Echo):** Status codes, response body/shape, headers, error responses. Plus framework-specific: route params, context values, middleware effects, binding validation.
- **gRPC service:** Status codes, response fields, error details, streaming behavior.
- **Database operation:** Query correctness (sqlmock), transaction handling, connection errors, empty results.
- **Goroutine/concurrent:** Race-free (`-race`), channel completion within timeout, WaitGroup completes, context cancellation propagates.

---

## Phase 4 — Test Generation

Generate test files using Go-specific syntax. Every generated test follows the Arrange-Act-Assert pattern and targets meaningful behavior, not implementation details.

### Go test file header

```go
package calc

import (
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)
```

When testify is not available (fallback):

```go
package calc

import "testing"
```

### Mocking patterns (condensed)

**Preferred strategies by mocking_strategy config:**
- **`interface_fakes`** (default): Create simple fake structs implementing the interface. Override fields for behavior control. No framework needed.
- **`testify_mock`**: Use `mock.Mock` with `.On()`/`.Return()` for interaction testing. Call `repo.AssertExpectations(t)` to verify all expectations met.
- **`gomock`**: Use `mockgen` for type-safe generated mocks. `EXPECT()` + `gomock.Eq()`/`gomock.Any()` for precise matching.

**Common mocks:** HTTP → `httptest.NewServer` with handler returning canned responses. Environment → `t.Setenv()`. Filesystem → `t.TempDir()`. Database → `go-sqlmock` or interface boundary mock.

> **On-demand load:** For complete mocking code examples (interface fakes, testify/mock, gomock, HTTP server, environment, filesystem), test helper function patterns (newUser, newUserList), table-driven test patterns, and the full well-generated test file example, read `references/generate/go/phase4-generation-detail.md`.

### Test naming convention

Every test name describes the specific scenario and expected outcome. Follow the pattern: `Test{Unit}_{Behavior}_when_{Condition}` or use descriptive `t.Run` names in table-driven tests.

```
Good examples:
  func TestCalculateDiscount_ReturnsReducedPrice_WhenPercentageIsValid(t *testing.T) {}
  func TestFetchUser_ReturnsNetworkError_WhenFetchFails(t *testing.T) {}
  func TestCart_ShowsEmptyState_WhenItemsListIsEmpty(t *testing.T) {}

Bad examples (never generate these):
  func TestWorks(t *testing.T) {}
  func TestHandlesError(t *testing.T) {}
  func Test1(t *testing.T) {}
  func TestTheFunction(t *testing.T) {}
```

### Generation rules

1. **Arrange-Act-Assert in every test.** Separate sections with blank lines.
2. **Error path tests alongside happy paths.** Every `(result, error)` return gets error path tests.
3. **No test for code-generated files.** Skip `// Code generated by` files.
4. **Helper functions for all test data.** No hardcoded struct literals repeated across tests.
5. **Mock at boundaries only.** External services, never internal utility functions.
6. **Specific assertions.** Use `assert.Equal(t, expected, actual)`. Avoid bare `assert.True(t, ok)`.
7. **Proper cleanup.** Use `t.Cleanup()`, `t.TempDir()`, `t.Setenv()`.
8. **`*_test.go` suffix required.** No exceptions.
9. **Correct package declaration.** Match existing convention (white-box or black-box).
10. **All imports must be used.** Run `goimports` on generated files.
11. **Check all error returns.** Never use `_` for error returns in tests.
12. **Use `require` for setup, `assert` for behavioral assertions.**

---

## Phase 5 — Compilation Verification (condensed)

Go's strict compilation rules require every generated test to pass `go vet` → `go build` → `go test -run='^$'` (3-stage pipeline).

> **Iteration budget:** Before each Phase 5 execution, decrement the global iteration budget per the Global Iteration Budget section in `references/generate/pipeline-shared.md`. If the budget is exhausted, halt and present the diagnostic summary.

> **On-demand load:** When compilation verification is needed, read `references/generate/go/phase5-compilation.md`. Apply the auto-fix patterns (unused imports, import cycles, undefined symbols, type mismatches, syntax errors, wrong package declarations, missing go.sum entries, build tag mismatches) and retry loop defined there.

---

## Phase 6 — Execution Verification (condensed)

Run generated tests with `go test -v -race -timeout {timeout} -coverprofile=coverage.out -covermode={mode} ./path/to/package/`. Parse NDJSON output for pass/fail/skip. Handle exit codes: 0=pass, 1=failures, 2=invalid args. Fix-and-rerun loop up to `max_retries`. After passing: run race detection verification and coverage delta.

> **Iteration budget:** Before each Phase 6 execution, decrement the global iteration budget per the Global Iteration Budget section in `references/generate/pipeline-shared.md`. If the budget is exhausted, halt and present the diagnostic summary.

> **On-demand load:** When execution verification is needed, read `references/generate/go/phase6-execution.md`. Run tests, analyze failures using the root cause table, apply the fix-and-rerun loop, verify race detection, and measure coverage delta as defined there.

---

## Phase 7 — Quality Audit (condensed)

Score each test file on the 0-100 rubric (Assertion Quality 30, Test Structure 20, Independence 20, Coverage Value 15, Maintainability 15). Detect anti-patterns (critical/high/medium/low severity). Run 5-run stability test.

> **On-demand load:** When quality audit scoring, anti-pattern detection, or flakiness testing is needed, read `references/generate/go/phase7-quality-audit.md`. Apply the scoring rubric, anti-pattern checks (critical through low), auto-fix capability, and stability testing defined there.

---

## HITL Gate

> **Shared section:** See HITL Gate Core in `references/generate/pipeline-shared.md`.

Summary sections: **Files Generated** (test count + quality score per file), **Coverage Delta** (before → after per source), **Quality Scores** (avg/highest/lowest), **Race Detection** results, **Flagged Items** (below threshold, missing scenarios, anti-patterns), **Source Behavior Notes** (source bugs discovered).

**Write-to-disk criteria:** Write when all conditions met: (1) score ≥ threshold for every file, (2) all tests pass, (3) no critical/high anti-patterns, (4) 5/5 stability, (5) no races. Score 50-69: write but flag. Score <50: do not write, present for review. Compilation/execution failures: do not write, present failure details.

**User approval actions:** Approve all, approve specific files, request regeneration, or request manual edit.

---

## Output

After successful completion, the following artifacts exist:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Generated test files | Same directory as source (e.g., `calc/discount_test.go`) | Test files with `_test.go` suffix matching Go naming convention |
| Coverage profile | `coverage.out` (temporary) | Coverage data for delta calculation |
| Updated reports | `.bestest/reports/` | Coverage metrics and quality scores |
| Updated TESTING.md | Repo root | New test inventory reflecting generated tests |
| Updated config state | `.bestest/config.yaml` | `state.last_generate` timestamp updated |

### Test file placement

Generated test files follow Go's standard: same directory as source file with `_test.go` suffix. Package declaration matches source (white-box default) or uses `xxx_test` convention if existing tests use black-box pattern.

### Config state update

> **Shared section:** See Config State Update in `references/generate/pipeline-shared.md`.

---

## Error Handling

> **Shared section:** See Error Handling Stub Pattern in `references/generate/pipeline-shared.md`. For Go, error handling detail is at `references/generate/go/error-handling.md`.

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
  "spoke": "spoke-generate-go",
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

> **Shared section:** See Downstream Reference Core in `references/generate/pipeline-shared.md`. Go additionally supports `/bestest run` (execute the full test suite with unified result capture).

### Reference Links

| Reference File | Purpose |
|---------------|---------|
| `references/go-decision-tree.md` | Framework selection logic for Go projects |
| `references/go-generation-guide.md` | Go-specific test patterns, quality rubric, anti-patterns |
| `references/anti-patterns.md` | Cross-language test smell catalog |
| `references/config-schema.md` | Full config.yaml schema documentation (including `go.*` block) |
| `references/spoke-run.md` | Test execution spoke (supports go test) |
| `references/spoke-fix.md` | Fix failing/flaky tests spoke |
| `references/templates/config-go.yaml` | Go config template |
