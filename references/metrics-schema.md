# Metrics Store Schema

Complete reference for `.bestest/state/metrics.json` — the continuously-updated metrics store that aggregates test health data from every state-changing spoke.

Every state-changing spoke (scan, run, fix, generate, migrate, doctor, coverage, report, config) writes to this file via the shared metrics-update protocol. The init spoke creates the initial file with sensible defaults. No other file in `.bestest/` provides this cross-spoke aggregate view.

---

## JSON Shape

```json
{
  "schemaVersion": "1.0",
  "lastUpdated": "string (ISO 8601)",
  "lastWriteConflict": {
    "timestamp": "string (ISO 8601)",
    "spoke": "string",
    "action": "string"
  },
  "healthScore": {
    "overall": 0.0,
    "breakdown": {
      "coverage": 0.0,
      "flakiness": 0.0,
      "passRate": 0.0,
      "freshness": 0.0,
      "mutation": 0.0
    }
  },
  "coverage": {
    "current": {
      "lines": 0.0,
      "branches": "number | \"n/a\"",
      "functions": 0.0,
      "statements": 0.0
    },
    "target": 0.0,
    "trend": [
      {
        "timestamp": "string (ISO 8601)",
        "lines": 0.0,
        "branches": "number | \"n/a\"",
        "functions": 0.0,
        "statements": 0.0
      }
    ],
    "trendMaxLength": 50
  },
  "tests": {
    "total": 0,
    "passing": 0,
    "failing": 0,
    "skipped": 0,
    "byType": {
      "unit": 0,
      "integration": 0,
      "e2e": 0
    }
  },
  "flakiness": {
    "flakyTests": [
      {
        "file": "string",
        "name": "string",
        "failPassRatio": 0.0,
        "signals": ["string"],
        "lastSeen": "string (ISO 8601)"
      }
    ],
    "overallFlakeRate": 0.0
  },
  "runs": {
    "total": 0,
    "history": [
      {
        "timestamp": "string (ISO 8601)",
        "spoke": "string",
        "scope": "string (suite filter: \"all\" | \"unit\" | \"integration\" | \"e2e\" | \"generated\")",
        "total": 0,
        "passed": 0,
        "failed": 0,
        "skipped": 0,
        "duration_ms": 0,
        "coverage": {
          "lines": 0.0,
          "branches": "number | \"n/a\"",
          "functions": 0.0,
          "statements": 0.0
        }
      }
    ],
    "historyMaxLength": 100
  },
  "modules": {
    "entries": [
      {
        "path": "string",
        "tests": 0,
        "passing": 0,
        "coverage": {
          "lines": 0.0,
          "branches": "number | \"n/a\"",
          "functions": 0.0,
          "statements": 0.0
        }
      }
    ]
  },
  "slowest": {
    "tests": [
      {
        "file": "string",
        "name": "string",
        "duration_ms": 0
      }
    ],
    "maxLength": 10
  },
  "failures": {
    "heatMap": [
      {
        "file": "string",
        "count": 0,
        "lastFailed": "string (ISO 8601)"
      }
    ],
    "maxLength": 20
  },
  "activity": [
    {
      "timestamp": "string (ISO 8601)",
      "spoke": "string",
      "action": "string",
      "summary": "string"
    }
  ],
  "activityMaxLength": 200
}
```

---

## Field Descriptions

### `schemaVersion`

- **Type:** `string`
- **Required:** Yes
- **Default:** `"1.0"`
- **Policy:** Per `schema-contract.md` — semver-minor (`"MAJOR.MINOR"`). MAJOR incremented on breaking changes (field removal/rename/type change). MINOR incremented on additive changes.

### `lastUpdated`

- **Type:** `string` (ISO 8601)
- **Required:** Yes
- **Default:** ISO 8601 timestamp at creation time
- **Updated by:** Every state-changing spoke on every invocation.
- **Purpose:** Quick staleness check — if `lastUpdated` is older than the caller's threshold, the data may not reflect the current state.

### `lastWriteConflict`

| `lastWriteConflict` | object | Optional | Present when a lock acquisition failed and the spoke proceeded with best-effort write. Fields: `{timestamp: string, spoke: string, action: string}`. Omitted when no conflicts have occurred. |

### `healthScore`

Composite score (0.0–1.0) reflecting overall test suite health. Designed for the S05 dashboard and agent decision-making.

| Sub-field | Range | Description |
|-----------|-------|-------------|
| `overall` | 0.0–1.0 | Weighted average of breakdown scores. |
| `breakdown.coverage` | 0.0–1.0 | `coverage.current.lines / coverage.target` (capped at 1.0). `"n/a"` coverage fields excluded. |
| `breakdown.flakiness` | 0.0–1.0 | `1.0 - overallFlakeRate`. No flaky tests = 1.0. |
| `breakdown.passRate` | 0.0–1.0 | `tests.passing / max(tests.total, 1)`. |
| `breakdown.freshness` | 0.0–1.0 | 1.0 if `lastUpdated` is within 24 hours, linearly decays to 0.0 over 7 days. |
| `breakdown.mutation` | 0.0–1.0 | Mutation score if mutation testing is enabled; otherwise `null` (excluded from `overall`). |

**Overall formula:**
```
activeScores = filter non-null breakdown values
overall = average(activeScores)  // 0 if no active scores
```

### `coverage`

Coverage data aggregated across runs. Reflects the most recent coverage snapshot and a bounded trend history.

| Sub-field | Description |
|-----------|-------------|
| `current` | Latest coverage percentages by metric type. Branches can be `"n/a"` per MEM045 (Python functions, Go branches). |
| `target` | From `config.yaml` `coverage.target` (default 80). Stored as 0–100 integer. |
| `trend` | Array of historical coverage snapshots. Each entry is a timestamped copy of the `current` shape. |
| `trendMaxLength` | Maximum entries in `trend`. Oldest entries evicted on insert. Default: 50. |

### `tests`

Aggregate test counts across the suite.

| Sub-field | Description |
|-----------|-------------|
| `total` | Total number of tests discovered or run. |
| `passing` | Tests that passed on the most recent run. |
| `failing` | Tests that failed on the most recent run. |
| `skipped` | Tests skipped or pending. |
| `byType` | Breakdown by test type: `unit`, `integration`, `e2e`. Types not applicable to the project remain at 0. |

### `flakiness`

Flaky test tracking. Populated by `spoke-scan` and `spoke-run`.

| Sub-field | Description |
|-----------|-------------|
| `flakyTests[].file` | Test file path (relative to project root). |
| `flakyTests[].name` | Test name (describe/it title). |
| `flakyTests[].failPassRatio` | Ratio of failing runs to total runs (0.0–1.0). ≥0.3 is considered flaky. |
| `flakyTests[].signals` | Canonical kebab-case flakiness signals per MEM070 (e.g., `"uncontrolled-time"`, `"order-dependent"`, `"shared-state"`). |
| `flakyTests[].lastSeen` | ISO 8601 timestamp of the most recent flaky observation. |
| `overallFlakeRate` | `count(flakyTests) / max(tests.total, 1)`. 0.0 when no flaky tests detected. |

### `runs`

Run history across all spokes that execute tests.

| Sub-field | Description |
|-----------|-------------|
| `total` | Cumulative count of test runs recorded. |
| `history[].spoke` | Which spoke triggered the run (e.g., `"spoke-run"`, `"spoke-fix"`, `"spoke-scan"`). |
| `history[].total/passed/failed/skipped` | Run result counts. |
| `history[].duration_ms` | Total test execution time in milliseconds. |
| `history[].coverage` | Coverage snapshot from this run (same shape as `coverage.current`). |
| `history[].scope` | string | Optional | Test suite filter used during this run: `"all"`, `"unit"`, `"e2e"`, `"integration"`, or `"generated"` (for companion run reports from generate). Default: `"all"`. Mapped from the run report's `suiteFilter` field — run report `suiteFilter: "generated"` → metrics `history[].scope: "generated"`; `suiteFilter: "all"` → `scope: "all"`. Consumers (report, doctor, status) should use this field to distinguish companion/generated runs from full-suite runs when reading run history. |
| `history[].topFailures` | array | Optional | Bounded array (max 5) of `{file: string, name: string, error: string, category: string}` for the most impactful failures in this run. Empty if all tests passed. |
| `historyMaxLength` | Maximum entries in `history`. Oldest entries evicted on insert. Default: 100. |

### `modules`

Per-module/directory test health breakdown. Populated primarily by `spoke-scan` and `spoke-coverage`.

| Sub-field | Description |
|-----------|-------------|
| `entries[].path` | Directory or module path (relative to project root). |
| `entries[].tests` | Total tests in this module. |
| `entries[].passing` | Passing tests in this module. |
| `entries[].coverage` | Coverage for this module (same shape as `coverage.current`). |

### `slowest`

The slowest individual tests across recent runs. Useful for identifying performance bottlenecks.

| Sub-field | Description |
|-----------|-------------|
| `tests[].file` | Test file path. |
| `tests[].name` | Test name. |
| `tests[].duration_ms` | Test execution time in milliseconds. |
| `maxLength` | Maximum entries. Default: 10 (top-10 slowest). |

### `failures`

Failure heat map — files with the most failures across all recorded runs.

| Sub-field | Description |
|-----------|-------------|
| `heatMap[].file` | Test file path. |
| `heatMap[].count` | Cumulative failure count for this file. |
| `heatMap[].lastFailed` | ISO 8601 timestamp of the most recent failure. |
| `heatMap[].lastError` | string | Optional | Truncated error message from the most recent failure (max 500 chars). Empty string if no failures. |
| `heatMap[].errorCategory` | string | Optional | Error classification: `"assertion"`, `"timeout"`, `"runtime"`, `"infrastructure"`, or `"unknown"`. |
| `maxLength` | Maximum entries. Default: 20. |

### `activity`

Append-only activity log recording every spoke invocation that updates metrics.

| Sub-field | Description |
|-----------|-------------|
| `timestamp` | ISO 8601 timestamp of the activity. |
| `spoke` | Spoke identifier (e.g., `"spoke-scan"`, `"spoke-run"`). |
| `action` | What the spoke did (e.g., `"scan"`, `"run"`, `"fix"`, `"doctor"`). |
| `summary` | Human-readable one-line summary (e.g., `"12 tests passed, 2 failed (coverage 74%)"`). |
| `activityMaxLength` | Maximum entries. Oldest evicted. Default: 200. |

---

## Update Protocol

Every state-changing spoke follows this shared protocol when writing to `metrics.json`:

### Protocol Steps

```
0. Acquire lock on .bestest/state/.metrics.lock
   - Use flock with 5-second timeout (primary) or mkdir-based fallback
   - If lock cannot be acquired, proceed anyway with a warning (best-effort)
   - For the full lock acquisition and release protocol, see references/pre-flight-protocol.md → Concurrency Lock Protocol.
1. Read .bestest/state/metrics.json
2. Parse as JSON
3. If parse fails (corruption):
   a. Log warning: "metrics.json corrupted — recreating with defaults"
   b. Backup the corrupt file: `cp .bestest/state/metrics.json .bestest/state/metrics.json.corrupt.$(date +%s)`
      - Log the backup path so agents can locate it for forensic inspection
      - This must happen BEFORE recreating defaults to preserve evidence
   c. Initialize fresh metrics with schemaVersion "1.0" and default values
   d. Continue with step 5 (do NOT abort the spoke)
4. Validate schemaVersion — warn if MAJOR differs, proceed if MINOR differs
5. Merge spoke-specific data:
   - Update lastUpdated to current ISO 8601 timestamp
   - Spoke updates only its own section(s), leaves others unchanged
   - Append to bounded arrays (history, trend, activity), evicting oldest when over maxLength
   - Recalculate derived values (healthScore, overallFlakeRate, etc.)
6. Write back to .bestest/state/metrics.json (atomic write: write to temp file, then rename)
7. Update config.yaml state.last_metrics with current timestamp
   - Acquire .bestest/.config.lock before this write (per Ordered Locking Rule in references/pre-flight-protocol.md → Concurrency Lock Protocol: config → metrics ordering; when both files are written, lock config first, then metrics, and release in reverse)
8. Release lock on .bestest/state/.metrics.lock
   - flock: released automatically when the subshell/process exits
   - mkdir: remove the lock directory with rm -rf
```

> **Important:** When using `flock`, the entire read-modify-write cycle (Steps 0–8) **must execute in a single shell invocation** (typically a subshell) so the lock is held for the full duration. Splitting the steps across separate shell commands would release the lock between reads and writes, defeating the purpose. See `references/pre-flight-protocol.md` → Concurrency Lock Protocol for the copy-paste shell template.

### Spoke Responsibility Matrix

| Spoke | Sections Updated |
|-------|-----------------|
| `spoke-init` | Creates initial file with defaults. No section merges. |
| `spoke-scan` | `tests`, `flakiness`, `modules`, `slowest`, `activity` |
| `spoke-run` | `tests`, `runs`, `coverage`, `healthScore`, `slowest`, `failures`, `activity` |
| `spoke-fix` | `tests`, `runs`, `failures`, `activity` |
| `spoke-generate` | `tests`, `activity` |
| `spoke-migrate` | `runs`, `activity` |
| `spoke-doctor` | `healthScore`, `activity` |
| `spoke-coverage` | `coverage`, `healthScore`, `modules`, `activity` |
| `spoke-report` | `activity` |
| `spoke-config` | `coverage.target` (if changed), `activity` |

### Graceful Degradation

Per MEM109 and the pre-flight protocol, corruption handling is inlined:

- **File missing:** Treated as first-time creation. Spoke writes its section with defaults for all others.
- **Parse failure:** Log warning, recreate with defaults + current spoke's data. **Never abort the spoke** — metrics are observability, not a gate.
- **schemaVersion mismatch (MAJOR):** Log warning, attempt to read known fields, write back with current schema version.
- **schemaVersion mismatch (MINOR):** Proceed normally. Unrecognized fields are preserved (pass-through).

**Write conflict tracking:** When a spoke proceeds without a lock (best-effort fallback), it MUST set `lastWriteConflict: {timestamp, spoke, action}` at the top level of metrics.json. This makes concurrency contention observable in the dashboard and health checks. Clear this field only when a subsequent write succeeds with the lock acquired.

### Bounded Array Eviction

Arrays with `*maxLength` fields use FIFO eviction:
1. Append new entry to end of array.
2. If `array.length > maxLength`, remove entries from the beginning until `array.length === maxLength`.

This ensures the file remains bounded regardless of how many commands the user runs.

---

## Default Values (Initial State)

When `spoke-init` creates `metrics.json`, it uses these defaults:

```json
{
  "schemaVersion": "1.0",
  "lastUpdated": "<current ISO 8601>",
  "healthScore": {
    "overall": 0.0,
    "breakdown": {
      "coverage": 0.0,
      "flakiness": 1.0,
      "passRate": 0.0,
      "freshness": 1.0,
      "mutation": null
    }
  },
  "coverage": {
    "current": {
      "lines": 0.0,
      "branches": "n/a",
      "functions": 0.0,
      "statements": 0.0
    },
    "target": 80,
    "trend": [],
    "trendMaxLength": 50
  },
  "tests": {
    "total": 0,
    "passing": 0,
    "failing": 0,
    "skipped": 0,
    "byType": {
      "unit": 0,
      "integration": 0,
      "e2e": 0
    }
  },
  "flakiness": {
    "flakyTests": [],
    "overallFlakeRate": 0.0
  },
  "runs": {
    "total": 0,
    "history": [],
    "historyMaxLength": 100
  },
  "modules": {
    "entries": []
  },
  "slowest": {
    "tests": [],
    "maxLength": 10
  },
  "failures": {
    "heatMap": [],
    "maxLength": 20
  },
  "activity": [],
  "activityMaxLength": 200
}
```

---

## Dashboard Consumption (S05)

The S05 dashboard reads `metrics.json` directly. Key consumption patterns:

| Dashboard Widget | Metrics Field |
|-----------------|---------------|
| Health gauge | `healthScore.overall` + `healthScore.breakdown` |
| Coverage trend chart | `coverage.trend` (line chart over time) |
| Test result summary | `tests.total/passing/failing/skipped` |
| Flaky test alert list | `flakiness.flakyTests` |
| Run history timeline | `runs.history` |
| Module coverage map | `modules.entries` |
| Slowest tests table | `slowest.tests` |
| Failure hot spots | `failures.heatMap` |
| Activity feed | `activity` (most recent first) |

---

## Cross-Reference

- Schema contract: `references/schema-contract.md` (versioning policy)
- Config schema: `references/config-schema.md` (`state.last_metrics` field)
- Directory schema: `references/dot-bestest-schema.md` (file lifecycle)
- Pre-flight protocol: `references/pre-flight-protocol.md` (corruption handling)
- Flakiness signals: `references/scan-report-schema.md` (canonical signal names per MEM070)
