# Scan Report Schema Reference

Complete JSON schema for the scan report produced by `bestest scan`. Reports are written to `.bestest/reports/scan-<timestamp>.json` where `<timestamp>` is an ISO 8601 datetime string (e.g., `2024-07-15T143045Z`). Prior reports are preserved for trend analysis.

## Top-Level Structure

```json
{
  "schemaVersion": "1.2",
  "timestamp": "string (ISO 8601)",
  "configSnapshot": { ... },
  "summary": { ... },
  "coverage": { ... },
  "antiPatterns": [ ... ],
  "flakyTests": [ ... ],
  "gaps": [ ... ],
  "testInventory": [ ... ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schemaVersion` | string | **yes** | Schema version identifier (e.g., `"1.2"`). Used to detect breaking changes to the report shape. Incremented when fields are removed or renamed; not incremented for additive changes. See `references/schema-contract.md` for the full versioning policy. |
| `timestamp` | string | **yes** | ISO 8601 datetime of when the scan completed (e.g., `"2024-07-15T14:30:45.123Z"`) |
| `configSnapshot` | object | **yes** | Snapshot of `.bestest/config.yaml` at scan time. Identical shape to the config schema (see `references/config-schema.md`). Ensures reports are self-contained and reproducible. |
| `summary` | object | **yes** | Aggregate test metrics: counts and pass/fail/skip breakdown |
| `coverage` | object | **yes** | Code coverage metrics across lines, branches, functions, and statements. Null fields if coverage collection is disabled. |
| `antiPatterns` | array | **yes** | Test anti-patterns detected during quality analysis. May be empty. |
| `flakyTests` | array | **yes** | Tests identified as potentially flaky. May be empty. |
| `gaps` | array | **yes** | Coverage gaps — source files/modules with missing or insufficient test coverage. |
| `testInventory` | array | **yes** | Complete inventory of all discovered test files with metadata. |

### `configSnapshot` Fields

The configSnapshot is a deep snapshot of `.bestest/config.yaml` at scan time, following the same shape as the config schema (see `references/config-schema.md`). All fields listed in the config schema are captured:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `framework` | string | **yes** | Test framework: `vitest`, `jest`, `pytest`, `junit5`, or `go_testing` |
| `language` | string | no | Primary language: `javascript`, `typescript`, `python`, `java`, or `go` |
| `version` | string | **yes** | Config schema version string |
| `coverage` | object | **yes** | Coverage settings (enabled, target, provider, reporters) |
| `paths` | object | **yes** | Source/test glob patterns and ignore patterns |
| `e2e` | object | **yes** | E2E framework settings |
| `api` | object | **yes** | API testing settings |
| `mutation` | object | **yes** | Mutation testing settings |
| `contract` | object | **yes** | Contract testing settings |
| `chaos` | object | **yes** | Chaos testing settings |
| `performance` | object | **yes** | Performance testing settings |
| `ci` | object | **yes** | CI provider settings |
| `vitest` | object | no | Vitest-specific config (when `framework` is `vitest`) |
| `jest` | object | no | Jest-specific config (when `framework` is `jest`) |
| `pytest` | object | no | pytest-specific config (when `framework` is `pytest`) |
| `junit5` | object | no | JUnit 5-specific config (when `framework` is `junit5`) |
| `go` | object | no | Go-specific config (when `framework` is `go_testing`) |
| `monorepo` | object | **yes** | Monorepo detection settings |
| `generation` | object | **yes** | Test generation settings |
| `reports` | object | **yes** | Report retention settings |
| `state` | object | **yes** | Runtime state (last_scan, last_generate, etc.) |

Reports are self-contained: downstream tooling does not need to read `config.yaml` directly to understand the scan's configuration context.

---

## `summary`

Aggregate metrics about the test suite.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `totalTests` | integer | **yes** | Total number of individual test cases discovered |
| `totalTestFiles` | integer | **yes** | Total number of test files found |
| `passed` | integer | **yes** | Number of tests that passed |
| `failed` | integer | **yes** | Number of tests that failed |
| `skipped` | integer | **yes** | Number of tests that were skipped (`.skip`, `.todo`) |
| `testTypes` | object | **yes** | Breakdown of tests by category |

### `summary.testTypes`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `unit` | integer | **yes** | Number of unit test files |
| `integration` | integer | **yes** | Number of integration test files |
| `e2e` | integer | **yes** | Number of end-to-end test files |
| `snapshot` | integer | **yes** | Number of snapshot test files |

Test type classification is based on file location and naming conventions:
- **unit**: files in `src/` matching `*.test.{ts,tsx}` (not in `e2e/`, `integration/`, or `__tests__/integration/`)
- **integration**: files in `__tests__/integration/`, `test/integration/`, or files importing multiple modules
- **e2e**: files in `e2e/`, `tests/e2e/`, or files importing Playwright/Cypress
- **snapshot**: files containing `toMatchSnapshot` or `toMatchInlineSnapshot`

---

## `coverage`

Code coverage metrics parsed from the coverage tool output. All percentage values are rounded to one decimal place.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `lines` | object | **yes** | Line coverage metrics |
| `branches` | object | **yes** | Branch coverage metrics |
| `functions` | object | **yes** | Function coverage metrics |
| `statements` | object | **yes** | Statement coverage metrics |

### Coverage Metric Object (applies to `lines`, `branches`, `functions`, `statements`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `total` | integer | **yes** | Total number of items (e.g., total lines, total branches) |
| `covered` | integer | **yes** | Number of items covered by tests |
| `pct` | number | **yes** | Coverage percentage (0.0–100.0), rounded to 1 decimal |

When coverage collection is disabled (`coverage.enabled: false`), all fields are populated with `total: 0`, `covered: 0`, `pct: 0.0`.

---

## `antiPatterns`

Array of detected test anti-patterns. Each entry identifies one specific instance of an anti-pattern in a specific file. See `references/anti-patterns.md` for full pattern definitions.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | string | **yes** | Relative path to the test file (from project root, e.g., `"src/utils/format.test.ts"`) |
| `pattern` | string | **yes** | Anti-pattern identifier from the catalog (e.g., `"sleep-based-waits"`, `"missing-assertions"`) |
| `line` | integer | **yes** | Line number in the file where the pattern was detected. `-1` if line-level detection is not possible (e.g., whole-file patterns). |
| `severity` | string | **yes** | `"critical"`, `"high"`, `"medium"`, or `"low"` |
| `description` | string | **yes** | Human-readable description of what was found and why it's flagged |

### Anti-Pattern Identifiers

| Identifier | Severity | Brief Description |
|------------|----------|-------------------|
| `tautological-assertions` | critical | Assertion that always passes |
| `sleep-based-waits` | high | Fixed-delay waits instead of async primitives |
| `hardcoded-secrets` | critical | Credentials or API keys in test code |
| `test-interdependencies` | high | Tests that depend on shared mutable state |
| `missing-assertions` | critical | Test with no assertion calls |
| `empty-catch-blocks` | high | Error silently swallowed |
| `overly-broad-matchers` | medium | Assertions too permissive to catch regressions |
| `implementation-coupling` | medium | Tests asserting on private internals |
| `snapshot-drift` | medium | Overly large or frequently updated snapshots |
| `test-only-code-in-source` | low | Production code exported only for testing |
| `duplicate-test-logic` | low | Near-identical test blocks |
| `flaky-indicators` | high | Non-deterministic primitives in unit tests |

---

## `flakyTests`

Array of tests identified as potentially flaky. Flakiness is detected through a combination of static analysis signals, historical failure patterns, and execution time outliers.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | **yes** | Relative path to the test file (e.g., `"src/services/payment.test.ts"`) |
| `name` | string | **yes** | Full test name including describe blocks, joined with ` > ` (e.g., `"Payment Service > processPayment > handles timeout"`) |
| `signals` | string[] | **yes** | List of flakiness signals detected (see below) |
| `riskLevel` | string | **yes** | `"high"`, `"medium"`, or `"low"` |

### Flakiness Signals

| Signal | Description |
|--------|-------------|
| `uncontrolled-time` | Uses `Date.now()` or `new Date()` without mocking |
| `uncontrolled-random` | Uses `Math.random()` without seeding |
| `network-calls` | Makes real network calls in unit test context |
| `filesystem-access` | Reads/writes real filesystem without temp directory isolation |
| `shared-state` | Accesses shared mutable state without cleanup |
| `long-execution` | Execution time >2x the median test time |
| `order-dependent` | Test passes in isolation but fails in full suite (requires multiple runs to detect) |
| `env-dependent` | Reads `process.env` without explicit setup/teardown |
| `race-condition` | Uses concurrent operations without proper synchronization |

### Risk Level Determination

| Risk Level | Criteria |
|------------|----------|
| `high` | 3+ signals, OR any of: uncontrolled-time + network-calls, shared-state + order-dependent |
| `medium` | 2 signals, OR 1 high-severity signal (network-calls, shared-state) |
| `low` | 1 signal, OR long-execution only |

---

## `gaps`

Array of coverage gaps — source files that lack adequate test coverage. Each entry represents a source file and its testing status.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sourcePath` | string | **yes** | Relative path to the source file (e.g., `"src/services/payment.ts"`) |
| `hasTest` | boolean | **yes** | Whether a corresponding test file exists |
| `coverage` | number | **yes** | Line coverage percentage for this file (0.0–100.0), or `0.0` if no test exists |
| `priority` | string | **yes** | `"critical"`, `"high"`, `"medium"`, or `"low"` |
| `reason` | string | **yes** | Human-readable explanation of why this gap exists and what testing is needed |

### Priority Determination

| Priority | Criteria |
|----------|----------|
| `critical` | Source file has **no test file** AND is imported by ≥5 other files (high impact radius) |
| `high` | Source file has **no test file** AND is imported by 2–4 files, OR coverage < 30% on a file imported by ≥3 files |
| `medium` | Source file has a test but coverage < 60%, OR no test and imported by 0–1 files |
| `low` | Source file has a test but coverage < 80%, or is a utility/config file with low complexity |

### Gap Detection Algorithm

1. Enumerate all source files matching `paths.src` glob (excluding `paths.ignore`)
2. For each source file, check if a corresponding test file exists (matching `paths.test` glob with matching base name)
3. If a test exists, parse coverage data for the file's line percentage
4. Determine priority using the criteria above, incorporating import graph data from the StackProfile
5. Sort gaps by priority (critical first), then by coverage (ascending)

---

## `testInventory`

Complete inventory of all test files discovered during the scan, with metadata about each file.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `path` | string | **yes** | Relative path to the test file (e.g., `"src/components/Button.test.tsx"`) |
| `type` | string | **yes** | `"unit"`, `"integration"`, `"e2e"`, or `"snapshot"` |
| `tests` | integer | **yes** | Number of individual test cases in this file |
| `status` | string | **yes** | `"passed"`, `"failed"`, `"skipped"`, or `"mixed"` (some passed, some failed) |
| `lastRun` | string or null | **yes** | ISO 8601 timestamp of when this test was last executed, or `null` if not executed during this scan |

### Status Determination

| Status | Meaning |
|--------|---------|
| `passed` | All tests in the file passed |
| `failed` | One or more tests in the file failed |
| `skipped` | All tests in the file were skipped |
| `mixed` | Combination of passed, failed, and/or skipped tests in the same file |

---

## Example and Conventions

### Full Report Example

```json
{
  "schemaVersion": "1.2",
  "timestamp": "2024-07-15T14:30:45.123Z",
  "configSnapshot": {
    "framework": "vitest",
    "language": "typescript",
    "version": "1.0",
    "coverage": {
      "enabled": true,
      "target": 80,
      "provider": "v8",
      "reporters": ["text", "html", "json-summary"]
    },
    "paths": {
      "test": "src/**/*.{test,spec}.{ts,tsx}",
      "src": "src/**/*.{ts,tsx}",
      "ignore": ["**/node_modules/**", "**/dist/**", "**/.bestest/**"]
    },
    "e2e": { "enabled": true, "framework": "playwright" },
    "api": { "enabled": false, "framework": null, "base_url": "http://localhost:3000" },
    "mutation": { "enabled": false, "framework": null, "config_path": "stryker.conf.json", "threshold": 80 },
    "contract": { "enabled": false, "framework": null, "provider": null, "consumer": null },
    "chaos": { "enabled": false, "framework": null, "targets": [] },
    "performance": { "enabled": false, "framework": null, "config_path": null, "threshold_ms": 500 },
    "ci": { "enabled": true, "provider": "github-actions" },
    "vitest": {
      "config_path": "vitest.config.ts",
      "globals": false,
      "environment": "jsdom",
      "setup_files": [],
      "include": ["src/**/*.{test,spec}.{ts,tsx}"]
    },
    "monorepo": { "enabled": false, "tool": null, "packages": [] },
    "generation": {
      "quality_threshold": 0.7,
      "verify_compilation": true,
      "verify_pass": true,
      "max_retries": 2
    },
    "reports": { "max_retained": 50 },
    "state": { "last_scan": null, "last_generate": null, "last_run": null, "last_doctor": null, "version": "1.0" }
  },
  "summary": {
    "totalTests": 142,
    "totalTestFiles": 18,
    "passed": 135,
    "failed": 3,
    "skipped": 4,
    "testTypes": {
      "unit": 14,
      "integration": 2,
      "e2e": 1,
      "snapshot": 1
    }
  },
  "coverage": {
    "lines": { "total": 1842, "covered": 1523, "pct": 82.7 },
    "branches": { "total": 312, "covered": 234, "pct": 75.0 },
    "functions": { "total": 198, "covered": 167, "pct": 84.3 },
    "statements": { "total": 2104, "covered": 1756, "pct": 83.5 }
  },
  "antiPatterns": [
    {
      "file": "src/utils/format.test.ts",
      "pattern": "sleep-based-waits",
      "line": 42,
      "severity": "high",
      "description": "Uses `await sleep(2000)` instead of waitFor. Replace with proper async assertion."
    },
    {
      "file": "src/services/auth.test.ts",
      "pattern": "hardcoded-secrets",
      "line": 15,
      "severity": "critical",
      "description": "Contains what appears to be a real API key pattern. Replace with obviously-fake test value."
    },
    {
      "file": "src/components/Modal.test.tsx",
      "pattern": "missing-assertions",
      "line": 28,
      "severity": "critical",
      "description": "Test 'renders without crashing' executes render but has no expect() call."
    },
    {
      "file": "src/hooks/useDebounce.test.ts",
      "pattern": "flaky-indicators",
      "line": 31,
      "severity": "high",
      "description": "Uses Date.now() without vi.useFakeTimers(). Test output is non-deterministic."
    }
  ],
  "flakyTests": [
    {
      "path": "src/services/payment.test.ts",
      "name": "Payment Service > processPayment > handles network timeout",
      "signals": ["network-calls", "long-execution"],
      "riskLevel": "high"
    },
    {
      "path": "src/utils/dateUtils.test.ts",
      "name": "DateUtils > formatRelativeTime > shows '2 hours ago'",
      "signals": ["uncontrolled-time"],
      "riskLevel": "medium"
    }
  ],
  "gaps": [
    {
      "sourcePath": "src/services/payment.ts",
      "hasTest": false,
      "coverage": 0.0,
      "priority": "critical",
      "reason": "No test file found. Payment service is imported by 6 other modules — high impact radius."
    },
    {
      "sourcePath": "src/lib/validator.ts",
      "hasTest": true,
      "coverage": 23.5,
      "priority": "high",
      "reason": "Low coverage (23.5%). Validator is imported by 4 modules. Missing tests for edge cases and error paths."
    },
    {
      "sourcePath": "src/types/index.ts",
      "hasTest": false,
      "coverage": 0.0,
      "priority": "low",
      "reason": "Type-only file. Testing via compilation is sufficient — no runtime behavior to cover."
    }
  ],
  "testInventory": [
    {
      "path": "src/components/Button.test.tsx",
      "type": "unit",
      "tests": 8,
      "status": "passed",
      "lastRun": "2024-07-15T14:30:43.456Z"
    },
    {
      "path": "src/services/payment.test.ts",
      "type": "unit",
      "tests": 5,
      "status": "failed",
      "lastRun": "2024-07-15T14:30:44.789Z"
    },
    {
      "path": "e2e/checkout-flow.spec.ts",
      "type": "e2e",
      "tests": 3,
      "status": "passed",
      "lastRun": "2024-07-15T14:30:38.100Z"
    }
  ]
}
```

### Report File Naming

Reports use the pattern `scan-<timestamp>.json` where the timestamp is a compact ISO 8601 format:

- Format: `YYYYMMDDTHHmmssZ` (e.g., `scan-20240715T143045Z.json`)
- The `Z` suffix indicates UTC time
- This format sorts chronologically when listed alphabetically

### Report Retention

- Reports are retained up to the configurable limit defined by `reports.max_retained` in `.bestest/config.yaml` (default: 50)
- After each scan, if the number of `scan-*.json` files exceeds `reports.max_retained` (default: 50), the oldest reports are deleted (see spoke-scan.md Phase 7 Step 7)
- The newest report is always preserved regardless of the retention limit
- Downstream tooling can compare consecutive reports to detect:
  - Coverage regression (current coverage < previous coverage)
  - New anti-patterns introduced since last scan
  - Flaky test history (same test flagged across multiple scans)
  - Test count changes (tests added or removed)

### Cross-Reference

This schema is consumed by:
- **Scan spoke** (`references/spoke-scan.md`) — Step 7 (Generate Report) produces this structure
- **Generate spoke** (`references/spoke-generate.md`) — Reads gaps and anti-patterns to prioritize generation
- **TESTING.md** — Updated with a human-readable summary derived from this report
- **Config state** (`state.last_scan`) — Updated to the report's `timestamp` value after successful scan
- **Metrics store** (`references/metrics-schema.md`) — Scan results feed into `metrics.json` via spoke-scan's metrics-update protocol (tests, flakiness, modules, slowest, activity sections)
