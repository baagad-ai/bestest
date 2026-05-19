# /bestest generate

## Purpose

AI-powered test generation spoke implementing the full 7-phase pipeline. Generates production-quality tests for target source files, ensuring every generated test compiles, passes, covers meaningful behavior, and scores ≥ `quality_threshold` (default 0.7) on the assertion quality audit rubric from `references/ai-generation-guide.md`. Supports targeting specific files, untested modules, code type filtering, and critical-path prioritization.

The generate spoke is the primary value delivery command — it transforms scan insights into concrete test files. Every test it produces must be a net positive: compiling, passing, contributing real coverage, and free of the anti-patterns cataloged in `references/anti-patterns.md`.

## Prerequisites

- `.bestest/` directory with valid `config.yaml` (run `/bestest init` first)
- StackProfile at `.bestest/state/stack-profile.json` for framework-appropriate generation patterns
- Scan report with `gaps[]` and `testInventory[]` arrays (run `/bestest scan` first for optimal targeting)
- Scan report is not strictly required — the spoke can generate in degraded mode without it, using filesystem scanning instead of gap targeting

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
| `generation.verify_compilation` | boolean | `true` | Whether Phase 5 (compilation check) runs. Skip to speed up generation at the cost of type safety. |
| `generation.verify_pass` | boolean | `true` | Whether Phase 6 (execution check) runs. Skip to generate without running tests. |
| `generation.max_retries` | number | `2` | Maximum fix-and-rerun attempts in Phase 6 when generated tests fail. |
| `generation.parallel.enabled` | boolean | `true` | Allow parallel dispatch when target count meets threshold. Set `false` to force sequential processing. |
| `generation.parallel.min_targets` | number | `5` | Minimum source files to trigger parallel mode. Below this, always sequential. |
| `generation.parallel.group_size` | number | `5` | Max source files per worker when dispatching in parallel. |
| `generation.parallel.depth_limit` | number | `1` | Max dispatch recursion depth (always 1 — workers never spawn workers). |

### 2. Check for StackProfile

```
If .bestest/state/stack-profile.json does not exist:
  Print: "Warning: StackProfile not found. Will attempt framework detection from package.json."
  Set framework = detect from package.json devDependencies.
Else:
  Read and parse StackProfile JSON.
  Extract testFrameworks.existing, coverage.provider, monorepo, frontend, languages.
  If JSON parsing fails → see state corruption handling in references/generate/phase1-target-detail.md.
```

### 3. Confidence Gate

Confidence gate: See SKILL.md "Confidence Gate (R5)" — the orchestrator checks confidence before loading this spoke. If you reached this spoke, confidence already passed the gate.

### 4. Check for scan report

```
If no scan report exists in .bestest/reports/:
  Print: "Warning: No scan report found. Generation will use filesystem scanning."
  Set mode = "filesystem-scan", gaps = [], testInventory = [].
Else:
  Load most recent scan report. Extract gaps[], testInventory[], configSnapshot.
  Set mode = "scan-guided".
```

### 5. Validate artifact schemaVersions

```
Validate stack-profile.json schemaVersion ≤ 1.3 and scan-report.json schemaVersion ≤ 1.2.
If MAJOR version differs → error and exit.
If MINOR exceeds expected → warning and continue.
If missing → treat as "1.0" legacy. Continue.
See references/generate/phase1-target-detail.md for full validation algorithm.
```

---

## Phase 1 — Target Selection

Determine which source files to generate tests for. Four targeting modes operate with priority ordering: explicit path overrides all other modes.

> **On-demand load:** For path validation rules (5-step security validation, traversal rejection, canonicalization, boundary checks, file type verification), detailed targeting mode logic, and pre-flight detail (state corruption handling, framework detection fallback, schema version validation algorithm), read `references/generate/phase1-target-detail.md`.

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
Read the source file. Extract all named exports, default exports, classes, constants, and types. Classify exports by type — functions and classes are testable (high priority), constants are low priority, type/interface exports have no runtime behavior (skip). For each import, classify as pure-logic (no mock needed), side-effect (mock required: fs, fetch, axios, database), framework (use framework utilities: RTL, supertest), or internal-module (mock only if side effects).
<!-- END_UNTRUSTED_SOURCE -->

> **Shared section:** See Content Boundary Notice in `references/generate/pipeline-shared.md`.

### Step 2: Read existing tests

```
If a corresponding test file exists:
  Read it. Extract test descriptions and identify which exports/scenarios are already covered.
  Only generate tests for uncovered exports. Match existing patterns (mocking style, assertion style).
Else:
  All exports are generation targets.
```

> **Shared section:** See Taint Notice (Context7) in `references/generate/pipeline-shared.md`.

### Step 3: Fetch framework documentation via Context7

Use the Context7 helper from `references/context7-helper.md` to fetch version-specific documentation. For each framework, call `resolve_library({ libraryName, query })` then `get_library_docs({ libraryId, query, tokens })`.

**Fetch targets:**
- **Vitest** (libraryName: `"vitest"`, query: `"vi.mock vi.fn vi.spyOn useFakeTimers mocking patterns"`, tokens: 5000): Produces version-accurate Vitest mocking and assertion patterns.
- **Vitest coverage** (query: `"coverage configuration v8 istanbul"`, tokens: 3000): Coverage command and configuration patterns.
- **Jest** (libraryName: `"jest"`, query: `"jest.mock jest.fn jest.spyOn useFakeTimers"`, tokens: 5000): Jest mocking and assertion patterns. Only fetched when framework is jest.
- **React Testing Library** (libraryName: `"testing-library react"`, query: `"render screen queries getByRole getByText waitFor"`, tokens: 5000): RTL query and interaction patterns. Only fetched when frontend is react.

> **Shared section:** See Graceful Fallback (Context7) in `references/generate/pipeline-shared.md`. For JS/TS, the static fallback source is `references/ai-generation-guide.md`.

### Step 4: Dependency identification

For each side-effect dependency: Network calls → `vi.mock('axios')` or mock global fetch. Filesystem → `vi.mock('fs')` or `vi.mock('fs/promises')`. Database → `vi.mock` at the client module. Timers → `vi.useFakeTimers()`. Random → `vi.spyOn(Math, 'random')`. Environment → set in `beforeEach`, restore in `afterEach`. Internal modules with side effects → `vi.mock('./dependency')`.

### Step 5: Complexity estimation

Estimate cyclomatic complexity by counting branching (`if`, `switch`, ternary, `&&`, `||`), loops (`for`, `while`, `map`, `filter`), and error handling (`try/catch`). Map to test count: complexity 1-3 → 2-3 tests, 4-8 → 4-6, 9-15 → 6-10, 16+ → 10+ (consider suggesting source refactoring).

---

## Phase 3 — Test Strategy Selection

Map each target export to a test strategy using the code type heuristics from `references/ai-generation-guide.md` Phase 2. The strategy determines test structure, assertion style, and required utilities.

### Code Type → Strategy Mapping

| Code Type | Detection Heuristics | Strategy | Test Structure |
|-----------|---------------------|----------|----------------|
| **Pure function** | No side-effect imports, no DOM, returns computed value | Input/output assertions with boundary values | `test.each` with equivalence classes from ai-generation-guide.md Phase 3 |
| **React component** | Imports React, JSX return, uses hooks | Render + interaction + accessibility checks | RTL render → screen queries → userEvent interactions → assertions |
| **API route** | Imports Request/Response, Next.js route handler, Express middleware | Request/response with status codes and error cases | Construct real Request objects → call handler → assert Response shape |
| **State management** | Reducer pattern, store/dispatch, Zustand/Jotai/Redux imports | State transitions with before/after assertions | Given state + action → expect new state |
| **Async operation** | Returns Promise, uses async/await, fetch/axios calls | Proper async/await with cleanup, no sleep-based waits | Mock async boundary → test all promise states (resolve/reject/timeout) |
| **Class** | `class` keyword, constructor, methods, `this` usage | Constructor + method tests with instance isolation | Create instance → call method → assert result or side effect |
| **Utility/helper** | Small, focused, no side effects | Exhaustive input/output matrix | `test.each` covering all equivalence classes and boundaries |
| **Middleware** | Express/Next.js middleware pattern, request pipeline | Request pipeline with various inputs | Mock request/response → call middleware → assert response modification |

### Strategy selection per export

```
For each export in the target source file:
  1. Check import list for framework indicators (React, Express, Next.js)
  2. Check return type (JSX.Element → component, Promise → async, Response → API route)
  3. Check parameter types (Request → API route, state+action → reducer)
  4. Check for side-effect dependencies (determined in Phase 2 Step 4)
  5. Assign the matching strategy from the table above.
  6. Record required test utilities (RTL, supertest, factory functions).
```

### What to assert per strategy

- **Pure function:** Specific return values for each input class. Edge cases at boundaries. Error handling for invalid inputs.
- **React component:** Visible output (text, elements). User interaction results (clicks, typing). Accessibility attributes. Conditional rendering. Loading/error states.
- **API route:** Status codes (200, 201, 400, 401, 404, 500). Response body shape. Error message format. Authentication/authorization checks.
- **State management:** State after dispatch. Immutable updates. Edge cases (empty state, max size). Side effects triggered by state changes.
- **Async operation:** Successful resolution with expected data. Error handling (network failure, timeout, invalid response). Cleanup on cancellation. Race condition handling.

---

## Phase 4 — Test Generation

Generate test files using framework-specific syntax. Every generated test follows the Arrange-Act-Assert pattern and targets meaningful behavior, not implementation details.

### Framework-specific syntax

All examples use Vitest-first syntax. When the project uses Jest (detected from StackProfile or config.yaml `framework: jest`), translate to Jest equivalents.

**Vitest test file header:**
```typescript
import { describe, test, expect, vi, beforeEach, afterEach } from 'vitest';
import { functionUnderTest } from './module';
```

**Jest test file header (when framework is jest):**
```typescript
// Jest — APIs may be global depending on jest.globals config
import { functionUnderTest } from './module';
// If globals are not enabled, import explicitly:
// import { describe, test, expect, jest, beforeEach, afterEach } from '@jest/globals';
```

### Test naming convention

Every test name describes the specific scenario and expected outcome. Follow the pattern: `[unit] [behavior] when [condition]`.

```
Good: test('calculateDiscount returns reduced price when percentage is within valid range')
Bad:  test('works'), test('handles error'), test('test1')
```

> **On-demand load:** For the complete well-generated test file example, advanced mocking patterns (Vitest/Jest), factory function patterns, and dependency mocking reference, read `references/generate/phase4-generation-detail.md`.

### Generation rules

1. **Arrange-Act-Assert in every test.** Separate sections with blank lines. Never combine act and assert.
2. **Error path tests alongside happy paths.** Every exported function that can throw or return errors gets error path tests.
3. **No test for type-only exports.** Skip interfaces, type aliases, and enums with no runtime behavior.
4. **Factory functions for all test data.** No hardcoded objects repeated across tests.
5. **Mock at boundaries only.** External services (network, filesystem, database), never internal utility functions.
6. **Specific matchers.** Use `toBe` for exact values, `toEqual` for objects. Avoid `toBeTruthy` on non-boolean values.
7. **Proper cleanup.** `afterEach` restores fake timers and clears mocks. No leaked state between tests.

---

## Phase 5 — Compilation Verification

> **Iteration budget:** Before each Phase 5 execution, decrement the global iteration budget per the Global Iteration Budget section in `references/generate/pipeline-shared.md`. If the budget is exhausted, halt and present the diagnostic summary.

> **On-demand load:** When compilation verification is needed, read `references/generate/phase5-compilation.md`. Apply the auto-fix patterns and retry loop defined there.

---

## Phase 6 — Execution Verification

> **Iteration budget:** Before each Phase 6 execution, decrement the global iteration budget per the Global Iteration Budget section in `references/generate/pipeline-shared.md`. If the budget is exhausted, halt and present the diagnostic summary.

> **On-demand load:** When execution verification is needed, read `references/generate/phase6-execution.md`. Run tests, analyze failures, and apply the fix-and-rerun loop defined there.

### Write Companion Run Report

After execution verification completes (whether tests pass or fail), write a `run-<timestamp>.json` to `.bestest/reports/` using the same schema as spoke-run Phase 4. This ensures downstream spokes (especially fix) can consume the test execution results from generation verification without requiring a separate `/bestest run`.

**When to write:**
- Phase 6 ran test execution (i.e., `generation.verify_pass` is `true` in config)
- Tests were actually executed (not skipped due to compilation failure)

**What to include:**
- `schemaVersion`: "1.0"
- `timestamp`: Generation completion timestamp
- `framework`: From config
- `language`: From config
- `suiteFilter`: "generated" (to distinguish from full suite runs)
- `execution`: Timing and exit code from Phase 6 test run
- `summary`: Pass/fail counts from the verification run
- `tests[]`: Per-file results for generated tests only
- `coverage`: If collected during verification
- `errors[]`: Any errors from failed verification runs
- `companionTo`: "generate" (marks this as generation-related, not a full suite run)

**When to skip:** If `generation.verify_pass` is `false`, or if tests could not be executed (compilation failure), skip writing the companion run report.

---

## Phase 7 — Quality Audit

> **On-demand load:** When quality audit scoring, anti-pattern detection, or flakiness testing is needed, read `references/generate/phase7-quality-audit.md`. Apply the scoring rubric, anti-pattern checks, and flakiness testing defined there.

---

## HITL Gate

> **Shared section:** See HITL Gate Core in `references/generate/pipeline-shared.md`.

---

## Output

After successful completion, the following artifacts exist:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Generated test files | Configured test directory (per `paths.test`) | Test files matching naming convention (e.g., `pricing.test.ts`) |
| Run report (companion) | `.bestest/reports/run-<timestamp>.json` | Execution results from verification phase, consumable by fix/coverage/report |
| Updated reports | `.bestest/reports/` | Coverage metrics and quality scores |
| Updated TESTING.md | Repo root | New test inventory reflecting generated tests |
| Updated config state | `.bestest/config.yaml` | `state.last_generate` timestamp updated |

### Test file placement

| Source File | Generated Test File |
|-------------|-------------------|
| `src/utils/pricing.ts` | `src/utils/pricing.test.ts` |
| `src/components/SearchBar.tsx` | `src/components/SearchBar.test.tsx` |
| `src/api/users/route.ts` | `src/api/users/route.test.ts` |

> **Shared section:** See Config State Update in `references/generate/pipeline-shared.md`.

---

> **Shared section:** See Error Handling Stub Pattern in `references/generate/pipeline-shared.md`. For JS/TS, error handling detail is at `references/generate/error-handling.md`.

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
  "spoke": "spoke-generate",
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

> **Shared section:** See Downstream Reference Core in `references/generate/pipeline-shared.md`.
