# /bestest report

## Purpose

Aggregate data from run-results.json files (produced by `run`) and scan reports (produced by `scan`) into a single human-readable markdown report. The report provides a holistic view of test suite health: coverage heatmap, pass/fail trends, flaky test history, anti-pattern distribution, uncovered critical paths, and prioritized action items. It is a **terminal spoke** — it produces markdown for human consumption, not structured JSON for downstream tooling.

Use `/bestest report` after running `scan` and/or `run` to get a consolidated summary that would otherwise require reading multiple JSON files. The report is designed for developers, tech leads, and CI review — anyone who needs a quick, actionable overview of test quality.

The report command is **read-only**: it never re-runs tests, modifies source code, or changes configuration beyond updating `state.last_report` in `config.yaml`.

## Prerequisites

- `.bestest/` directory must exist with valid `config.yaml` (run `/bestest init` first)
- **At least one data source** must be present:
  - `run-*.json` files in `.bestest/reports/` (from prior `/bestest run` executions), OR
  - `scan-*.json` files in `.bestest/reports/` (from prior `/bestest scan` executions)
- `config.yaml` should contain `coverage.target` and `framework` for meaningful target comparison (falls back to defaults if absent)

## Pre-Flight Checks

Run these checks before loading data. They guard against invalid states and give the user early, actionable feedback.

> See **references/pre-flight-protocol.md** for the standard 3-step `.bestest/` validation pattern and spoke-specific variants.

### 1. Check for `.bestest/` with valid config

```
If .bestest/ does not exist:
  Print: "No .bestest/ directory found. Run /bestest init first to set up testing infrastructure."
  Exit. No report generated.

If .bestest/config.yaml does not exist:
  Print: ".bestest/config.yaml is missing. The config file is required for report generation."
  Print: "Run /bestest init to regenerate it, or restore it from version control."
  Exit.

If .bestest/config.yaml exists but is invalid YAML:
  Print: ".bestest/config.yaml contains invalid YAML and cannot be parsed."
  Print: "Fix the syntax error and re-run /bestest report."
  Exit.
```

Parse and extract fields used during report generation:
- `framework` — test framework name for report metadata
- `language` — primary language (`javascript`, `typescript`, `python`, `java`, `go`). Auto-detected during init. Printed in data source summary: `"Language: {language}"`
- `coverage.target` — numeric threshold for coverage comparison (default: `80` if absent)
- `coverage.enabled` — whether coverage collection is active
- `paths.src` — source file glob for module grouping
- `paths.test` — test file glob for context

### 2. Check for at least one data source

```
Glob for run reports:  .bestest/reports/run-*.json
Glob for scan reports: .bestest/reports/scan-*.json

If no run reports and no scan reports found:
  Print: "No report data found in .bestest/reports/."
  Print: "The report command needs test execution or scan data to aggregate."
  Print: "Run one of these first:"
  Print: "  /bestest run --coverage    — Execute tests and capture results"
  Print: "  /bestest scan              — Full quality audit with anti-pattern detection"
  Print: "After generating data, re-run /bestest report."
  Exit.

If data sources found:
  Print: "Found {R} run report(s) and {S} scan report(s) in .bestest/reports/."
  Continue.
```

### 3. Check config for coverage targets and framework info

```
If config.yaml has no coverage.target field:
  Print: "No coverage.target set in config.yaml. Using default target: 80%."
  Set target = 80

If config.yaml has no framework field:
  Print: "Warning: framework not specified in config.yaml."
  Print: "Report metadata will omit framework version info."
  Set framework = null

If coverage.enabled is false:
  Print: "Note: coverage.enabled is false. Run-based coverage trends may be incomplete."
  Continue (report still generated from available data)
```

### 4. Validate artifact schemaVersions

Reference: `references/schema-contract.md` for version policy and validation algorithm.

```
Validate run-results.json schemaVersion (for each run report found in Check 2):
  Expected version: "1.0" (current known version).
  If schemaVersion is missing:
    Print: "Error: run-results.json is missing schemaVersion. All run results must include schemaVersion."
    Print: "Re-run /bestest run to generate a versioned report."
    Skip this report — it may be from an incompatible version.
  If MAJOR version matches (1.x) and MINOR ≤ 0:
    Proceed normally.
  If MAJOR version matches but MINOR > 0:
    Print: "⚠ run-results.json schemaVersion {version} is newer than expected (1.0). Proceeding — unrecognized fields will be ignored."
    Continue with warning.
  If MAJOR version differs:
    Print: "Error: run-results.json schemaVersion {version} has an incompatible MAJOR version. Expected 1.x."
    Print: "Update bestest to the latest version."
    Skip this report.

Validate scan-report.json schemaVersion (for each scan report found in Check 2):
  Expected version: ≤ 1.2 (current known version).
  If schemaVersion is missing:
    Treat as version "1.0" (pre-versioning legacy). Print a note and continue.
  If MAJOR version matches (1.x) and MINOR ≤ 2:
    Proceed normally.
  If MAJOR version matches but MINOR > 2:
    Print: "⚠ scan-report.json schemaVersion {version} is newer than expected (≤ 1.2). Proceeding — unrecognized fields will be ignored."
    Continue with warning.
  If MAJOR version differs:
    Print: "Error: scan-report.json schemaVersion {version} has an incompatible MAJOR version. Expected 1.x."
    Print: "Update bestest to the latest version, or re-run /bestest scan to regenerate."
    Skip this report.
```

---

## Phase 1 — Load Data Sources

Read all available run and scan reports from `.bestest/reports/`, sorted chronologically. This phase builds the in-memory datasets that subsequent phases aggregate from.

### Execution Steps

1. **Read all run reports** — Glob for `run-*.json` files in `.bestest/reports/`. Sort by filename (timestamp-embedded names sort chronologically). For each file:

   ```
   Parse the JSON file.
   If parsing fails:
     Print: "Warning: Skipping corrupted run report: {filename}"
     Add to skippedFiles list.
     Continue to next file.

   Extract from each run-results.json:
     - timestamp: ISO 8601 string
     - summary: { totalTests, passed, failed, skipped, todo, totalTestFiles, passedFiles, failedFiles }
     - coverage: { collected, lines: { total, covered, pct }, branches: { total, covered, pct }, functions: { total, covered, pct }, statements: { total, covered, pct } }
     - execution.durationMs: total execution time
     - suiteFilter: which suite was run
     - framework: { name, version }
     - language: string ("javascript", "typescript", "python", "java", "go")
     - errors: array of error objects (for failure counts)
   ```

   After loading all run reports, build a language inventory:
   ```
   languages = Set of unique language values from all run reports
   isMultiLanguage = languages.length > 1
   Print: "Languages detected: {languages.join(', ')}"
   ```

2. **Read all scan reports** — Glob for `scan-*.json` files in `.bestest/reports/`. Sort by filename. For each file:

   ```
   Parse the JSON file.
   If parsing fails:
     Print: "Warning: Skipping corrupted scan report: {filename}"
     Add to skippedFiles list.
     Continue to next file.

   Extract from each scan report:
     - timestamp: ISO 8601 string
     - summary: { totalTests, totalTestFiles, passed, failed, skipped, testTypes }
     - coverage: { lines, branches, functions, statements } each with { total, covered, pct }
     - antiPatterns[]: { file, pattern, line, severity, description }
     - flakyTests[]: { path, name, signals[], riskLevel }
     - gaps[]: { sourcePath, hasTest, coverage, priority, reason }
     - testInventory[]: { path, type, tests, status, lastRun }
   ```

3. **Read config for targets** — Load coverage target and framework info from `config.yaml` (already parsed in Pre-Flight). Store as `configSnapshot` for the report header.

4. **Handle partial data gracefully** — Determine the available data mode:

   | Data Available | Report Mode | Description |
   |---------------|-------------|-------------|
   | Run + Scan | `full` | Complete report with all sections |
   | Scan only | `scan-only` | No pass/fail trends or duration trends from runs. Coverage heatmap from scan data. Anti-patterns, gaps, and flaky tests from scan. |
   | Run only | `run-only` | Pass/fail trends and coverage history from runs. No anti-pattern distribution, no flaky test detection, no gap analysis. Coverage heatmap from run coverage data if available. |

   Print: "Report mode: {mode} — {brief description of available sections}"

### Output

In-memory arrays: `runReports[]` (sorted oldest to newest), `scanReports[]` (sorted oldest to newest), `configSnapshot`, `reportMode`, `languages` (Set of unique language values), `isMultiLanguage` (boolean).

---

## Phase 2 — Compute Aggregations

Process the loaded data into the aggregated metrics that the report sections will display. Each sub-step produces one data block consumed by Phase 3.

### Pass/Fail Trends

Compare consecutive run reports to detect regressions and improvements. This analysis is only available when two or more run reports exist.

```
For each pair of consecutive run reports (sorted by timestamp):
  current  = runReports[i]
  previous = runReports[i-1]

  Compute deltas:
    testsDelta    = current.summary.totalTests - previous.summary.totalTests
    passedDelta   = current.summary.passed - previous.summary.passed
    failedDelta   = current.summary.failed - previous.summary.failed
    passRateDelta = (current.summary.passed / current.summary.totalTests * 100)
                    - (previous.summary.passed / previous.summary.totalTests * 100)

  Assign trend indicators:
    If passRateDelta > 0: arrow = "↑" with green indicator
    If passRateDelta < 0: arrow = "↓" with red indicator
    If passRateDelta == 0: arrow = "→" with neutral indicator

  Build trend entry:
    {
      from: previous.timestamp,
      to: current.timestamp,
      passRate: { previous: <pct>, current: <pct>, delta: <signed number>, arrow: "↑|↓|→" },
      totalTests: { previous: N, current: N, delta: signed N },
      failures: { previous: N, current: N, delta: signed N }
    }
```

For the most recent run, also compute the overall pass rate:
```
latestRun = runReports[last]
passRate = latestRun.summary.passed / latestRun.summary.totalTests * 100
```

If only one run report exists, skip trend comparison and show only the single data point.

**Per-language pass/fail breakdown (multi-language only):**

```
If isMultiLanguage:
  Group run reports by language
  For each language group:
    Compute pass rate from that language's reports:
      langPassRate = sum(passed) / sum(totalTests) * 100
    Build mini-trend entry with language label:
      {
        language: languageName,
        totalTests: sum of totalTests for this language,
        passed: sum of passed,
        failed: sum of failed,
        passRate: langPassRate,
        trend: computed from last two runs for this language
      }
  Sort per-language entries by pass rate ascending (worst first)
```

### Coverage Trends

Extract coverage percentages from consecutive run or scan reports to show coverage trajectory over time.

```
Collect coverage data points from all sources, sorted by timestamp:
  For each run report with coverage.collected === true:
    Add data point: { timestamp, source: "run", lines: pct, branches: pct, functions: pct, statements: pct }
  For each scan report with coverage data:
    Add data point: { timestamp, source: "scan", lines: pct, branches: pct, functions: pct, statements: pct }

Sort all data points by timestamp ascending.

For each consecutive pair of data points:
  Compute delta for each metric (lines, branches, functions, statements):
    delta = current.metric.pct - previous.metric.pct
    arrow = "↑" if delta > 0, "↓" if delta < 0, "→" if delta == 0

Build coverage history timeline:
  [
    { timestamp, lines: { pct, delta, arrow }, branches: { pct, delta, arrow }, ... },
    ...
  ]
```

If no coverage data exists in any source, skip this section and note it in the report.

### Flaky Test History

Aggregate flaky test data across all scan reports to identify tests flagged repeatedly.

```
flakyTestMap = Map<testIdentifier, { name, path, occurrences: [], riskLevels: [] }>

For each scan report:
  For each entry in flakyTests[]:
    key = entry.path + "::" + entry.name
    If key not in flakyTestMap:
      Add entry with first occurrence
    Else:
      Append this scan's timestamp to occurrences
      Append this scan's riskLevel to riskLevels

After processing all scans:
  For each entry in flakyTestMap:
    Compute aggregate risk:
      If occurrences.length >= 3: aggregateRisk = "high"
      Else if occurrences.length == 2: aggregateRisk = max(riskLevels)
      Else: aggregateRisk = riskLevels[0]

    Compute unique signals across all occurrences:
      allSignals = union of all signals[] from each occurrence

Sort by: aggregateRisk descending, then occurrences.length descending
```

This produces a consolidated flaky test list with cross-scan history.

### Anti-Pattern Distribution

Aggregate anti-patterns from all scan reports, grouped by severity and pattern type.

```
severityCounts = { critical: 0, high: 0, medium: 0, low: 0 }
patternCounts  = Map<patternId, { count, severity, description, files: [] }>

For each scan report (use only the most recent to avoid double-counting identical findings):
  For each entry in antiPatterns[]:
    severityCounts[entry.severity]++
    If entry.pattern in patternCounts:
      patternCounts[entry.pattern].count++
      patternCounts[entry.pattern].files.push(entry.file)
    Else:
      patternCounts[entry.pattern] = {
        count: 1,
        severity: entry.severity,
        description: entry.description,
        files: [entry.file]
      }

Sort patternCounts by severity (critical first), then by count descending.
```

### Coverage Heatmap

Build a per-file/module coverage table from the most recent scan or run data. Use emoji indicators for quick visual scanning.

```
Collect per-file coverage data:
  Priority 1: Most recent scan report's testInventory[] + gaps[]
    - For each gap: sourcePath, coverage (line pct)
    - For each testInventory entry: path, status

  Priority 2: Most recent run report (if it has per-file coverage from Istanbul)
    - Parse per-file coverage from coverage summary if available

If no per-file data available:
  Use aggregate coverage only — skip per-file heatmap and note in report.
```

**Language-aware heatmap:**

```
If isMultiLanguage:
  Add a "Language" column to the heatmap table
  Group modules by language first, then by path
  Use language-specific emoji prefix:
    🐍 Python
    ☕ Java
    🦫 Go
    📦 JS/TS
```

**Language-specific metric availability:**

| Language | Lines | Branches | Functions | Statements | Notes |
|----------|-------|----------|-----------|------------|-------|
| JS/TS | ✅ | ✅ | ✅ | ✅ | Istanbul/V8 — all metrics |
| Python | ✅ | ✅ | ✅ | n/a | coverage.py — no statements metric |
| Java | ✅ | ✅ | ✅ | ✅ | JaCoCo — all metrics |
| Go | ✅ | n/a | ✅ | ✅ | go test — no branches metric |

When a metric is unavailable for a language, show `n/a` in the corresponding column instead of a percentage.

```
For each source file with coverage data:
  Assign emoji indicator:
    coverage >= 80%: 🟢 (good)
    coverage >= 50%: 🟡 (needs attention)
    coverage >  0%:  🔴 (critical gap)
    coverage == 0%:  ⬛ (no test)

Group by module (first two path segments, e.g., "src/services/"):
  For each module:
    Compute average coverage across files
    Count files in each emoji category
    Sort modules by average coverage ascending (worst first)
```

### Duration Trends

Extract execution duration from run reports to show test suite speed over time.

```
For each run report:
  Extract execution.durationMs
  Convert to seconds: durationSec = durationMs / 1000

Build duration timeline:
  [
    { timestamp, durationMs, durationSec, suiteFilter, totalTests },
    ...
  ]

If two or more data points:
  Compute average duration
  Identify slowest and fastest runs
  Compute delta between last two runs:
    delta = latest.durationMs - previous.durationMs
    arrow = "↑" if slower, "↓" if faster, "→" if same
```

### Output

Aggregated data blocks: `passFailTrends[]`, `coverageTimeline[]`, `flakyTestHistory[]`, `antiPatternDistribution`, `coverageHeatmap`, `durationTrends[]`, `perLanguageBreakdown[]` (populated when isMultiLanguage).

---

## Phase 3 — Generate Markdown Report

Assemble the aggregated data into a structured markdown document. Each section is generated conditionally based on available data — sections that lack source data are omitted with a brief note.

### Report Header

```markdown
# bestest report

Generated: {current ISO 8601 timestamp}
Project: {project directory name}
Language: {language from config, or "multi-language ({list})" if isMultiLanguage}
Framework: {framework name and version, or "unknown"}
Data sources: {R} run reports, {S} scan reports
Report mode: {full|scan-only|run-only}

---
```

### Section 1 — Summary

Key metrics from the most recent data sources. Always present.

```markdown
## Summary

| Metric | Value |
|--------|-------|
| Total tests | {latest totalTests} |
| Pass rate | {passRate}% |
| Total test files | {latest totalTestFiles} |
| Coverage (lines) | {latest lines.pct}% |
| Coverage target | {target}% |
| Target status | {MET ✅ / NOT MET ❌} |
| Flaky tests | {count from latest scan, or "N/A"} |
| Anti-patterns | {count from latest scan, or "N/A"} |
| Execution time | {latest duration formatted, or "N/A"} |
```

If no run data exists, test counts and pass rate come from the most recent scan's summary. If no scan data exists, flaky and anti-pattern counts show "N/A — run /bestest scan for anti-pattern analysis".

**Per-language pass rates (multi-language only):**

When `isMultiLanguage`, add per-language rows to the summary table after the overall pass rate row:

```markdown
| Pass rate (Python) | {pct}% |
| Pass rate (Java) | {pct}% |
| Pass rate (Go) | {pct}% |
```

One row per detected language, using the language-specific emoji prefix (🐍 Python, ☕ Java, 🦫 Go, 📦 JS/TS). When single-language, the summary table is unchanged (no per-language rows).

### Section 2 — Coverage Heatmap

Per-module coverage table with emoji indicators. Present when per-file coverage data is available.

{If isMultiLanguage:}

```markdown
## Coverage Heatmap

| Language | Module | Files | Avg Coverage | Status | Breakdown |
|----------|--------|-------|-------------|--------|-----------|
| 📦 JS/TS | src/services/ | 8 | 45.2% | 🔴 | 🟢 2 🟡 1 🔴 3 ⬛ 2 |
| 📦 JS/TS | src/components/ | 12 | 72.1% | 🟡 | 🟢 6 🟡 3 🔴 2 ⬛ 1 |
| 🐍 Python | src/processors/ | 5 | 88.4% | 🟢 | 🟢 4 🟡 1 🔴 0 ⬛ 0 |
| ☕ Java | src/services/ | 6 | 30.0% | 🔴 | 🟢 0 🟡 0 🔴 4 ⬛ 2 |
| 🦫 Go | pkg/handlers/ | 3 | 75.0% | 🟡 | 🟢 2 🟡 0 🔴 1 ⬛ 0 |

Legend: 🟢 ≥80% | 🟡 50-79% | 🔴 <50% | ⬛ no test
```

Modules are grouped by language first, then sorted by average coverage ascending within each language group.

{If single-language, original format:}

```markdown
## Coverage Heatmap

| Module | Files | Avg Coverage | Status | Breakdown |
|--------|-------|-------------|--------|-----------|
| src/services/ | 8 | 45.2% | 🔴 | 🟢 2 🟡 1 🔴 3 ⬛ 2 |
| src/components/ | 12 | 72.1% | 🟡 | 🟢 6 🟡 3 🔴 2 ⬛ 1 |
| src/utils/ | 5 | 88.4% | 🟢 | 🟢 4 🟡 1 🔴 0 ⬛ 0 |
| src/middleware/ | 3 | 30.0% | 🔴 | 🟢 0 🟡 0 🔴 2 ⬛ 1 |

Legend: 🟢 ≥80% | 🟡 50-79% | 🔴 <50% | ⬛ no test
```

Modules are sorted by average coverage ascending (worst coverage first) to draw attention to problem areas. If no per-file data is available, replace the table with:

```markdown
## Coverage Heatmap

Per-file coverage data not available. Aggregate coverage from the most recent data source:

| Metric | Coverage | Target | Status |
|--------|----------|--------|--------|
| Lines | {pct}% | {target}% | {status} |
| Branches | {pct}% | {target}% | {status} |
| Functions | {pct}% | {target}% | {status} |
| Statements | {pct}% | {target}% | {status} |

Run /bestest scan for detailed per-file coverage analysis.
```

### Section 3 — Flaky Test Trends

List of tests flagged as flaky across scan reports, with risk levels and occurrence counts. Present when scan data with flakyTests[] is available.

```markdown
## Flaky Test Trends

{If flaky tests found:}

Found {total} flaky test(s) across {scanCount} scan(s).

| # | Test | File | Risk | Occurrences | Signals |
|---|------|------|------|------------|---------|
| 1 | {name} | {path} | 🔴 high | 3 | network-calls, long-execution |
| 2 | {name} | {path} | 🟡 medium | 2 | uncontrolled-time |
| 3 | {name} | {path} | 🟢 low | 1 | env-dependent |

{If no flaky tests found in any scan:}

No flaky tests detected. All scans returned clean flakyTests[] arrays.

{If no scan data available:}

Flaky test analysis requires scan data. Run /bestest scan to enable flaky test detection.
```

Risk level indicators: 🔴 high, 🟡 medium, 🟢 low. Tests with 3+ occurrences are always high risk regardless of original classification.

### Section 4 — Coverage History

Text-based trend visualization showing coverage trajectory over time. Present when two or more data points with coverage exist.

```markdown
## Coverage History

Coverage over {dataPointCount} data points ({earliest date} → {latest date}):

{If isMultiLanguage, include Language column:}

| Date | Language | Lines | Δ | Branches | Δ | Functions | Δ | Statements | Δ |
|------|----------|-------|---|----------|---|-----------|---|-------------|---|
| Jul 10 | 📦 JS/TS | 78.2% | — | 65.1% | — | 80.0% | — | 77.5% | — |
| Jul 10 | 🐍 Python | 72.0% | — | n/a | — | 68.5% | — | n/a | — |
| Jul 12 | 📦 JS/TS | 80.1% | ↑ +1.9 | 68.3% | ↑ +3.2 | 81.2% | ↑ +1.2 | 79.0% | ↑ +1.5 |
| Jul 12 | ☕ Java | 85.0% | — | 78.0% | — | 90.0% | — | 84.0% | — |

{If single-language, omit Language column — table format unchanged:}

| Date | Lines | Δ | Branches | Δ | Functions | Δ | Statements | Δ |
|------|-------|---|----------|---|-----------|---|-------------|---|
| Jul 10 | 78.2% | — | 65.1% | — | 80.0% | — | 77.5% | — |
| Jul 12 | 80.1% | ↑ +1.9 | 68.3% | ↑ +3.2 | 81.2% | ↑ +1.2 | 79.0% | ↑ +1.5 |
| Jul 15 | 82.7% | ↑ +2.6 | 75.0% | ↑ +6.7 | 84.3% | ↑ +3.1 | 83.5% | ↑ +4.5 |

Overall trend: ↑ Improving (lines coverage +4.5% over period)

{If coverage declining:}
Overall trend: ↓ Declining (lines coverage -{N}% over period) — investigate recent changes

{If only one data point:}
Only one data point available. Run additional /bestest run or /bestest scan executions to build trend history.

{If no coverage data:}
No coverage data found in any report. Enable coverage collection:
  /bestest run --coverage
  /bestest scan
```

The delta column uses arrows (↑↓→) with signed percentage changes. The "Overall trend" line summarizes the trajectory.

### Section 5 — Uncovered Critical Paths

Source files with high-priority coverage gaps from scan data. Present when scan data with gaps[] is available and contains critical or high priority entries.

```markdown
## Uncovered Critical Paths

{If critical/high gaps exist:}

Found {criticalCount} critical and {highCount} high-priority coverage gaps:

### Critical (no test, high impact)

| # | Source File | Has Test | Coverage | Reason |
|---|-------------|----------|----------|--------|
| 1 | src/services/payment.ts | ❌ | 0.0% | No test file. Imported by 6 modules. |
| 2 | src/middleware/auth.ts | ❌ | 0.0% | No test file. Authentication module. |
| 3 | src/lib/validator.ts | ✅ | 23.5% | Low coverage. Imported by 4 modules. |

### High Priority

| # | Source File | Has Test | Coverage | Reason |
|---|-------------|----------|----------|--------|
| 1 | src/hooks/useAuth.ts | ❌ | 0.0% | No test file. Auth-related module. |
| 2 | src/api/handlers.ts | ✅ | 15.2% | Missing error path tests. Imported by 3 modules. |

{If only medium/low gaps exist:}

No critical or high-priority gaps found. {mediumCount} medium and {lowCount} low-priority gaps exist.
Run /bestest coverage for detailed gap analysis.

{If no scan data available:}

Coverage gap analysis requires scan data. Run /bestest scan to identify uncovered critical paths.
```

Only critical and high priority gaps are shown in this section. The full gap list is available via `/bestest coverage`.

### Section 6 — Anti-Pattern Distribution

Anti-patterns from the most recent scan, grouped by severity and pattern type. Present when scan data with antiPatterns[] is available.

```markdown
## Anti-Pattern Distribution

{If anti-patterns found:}

{total} anti-pattern(s) detected in the most recent scan:

### By Severity

| Severity | Count |
|----------|-------|
| 🔴 Critical | {criticalCount} |
| 🟠 High | {highCount} |
| 🟡 Medium | {mediumCount} |
| 🟢 Low | {lowCount} |

### By Pattern Type

| Pattern | Severity | Count | Example File |
|---------|----------|-------|-------------|
| missing-assertions | critical | 3 | src/components/Modal.test.tsx:28 |
| sleep-based-waits | high | 2 | src/utils/format.test.ts:42 |
| hardcoded-secrets | critical | 1 | src/services/auth.test.ts:15 |
| flaky-indicators | high | 1 | src/hooks/useDebounce.test.ts:31 |
| implementation-coupling | medium | 4 | src/services/payment.test.ts:55 |
| snapshot-drift | medium | 2 | src/components/Table.test.tsx:120 |
| test-only-code-in-source | low | 1 | src/lib/validator.ts:88 |
| duplicate-test-logic | low | 2 | src/utils/format.test.ts:30 |

{If no anti-patterns found:}

No anti-patterns detected. The test suite follows recommended patterns.

{If no scan data available:}

Anti-pattern analysis requires scan data. Run /bestest scan for quality pattern detection.
```

Pattern types are sorted by severity (critical first), then by count descending. The example file column shows the first file where the pattern was found with its line number.

### Section 7 — Prioritized Action Items

Auto-generated action items from the intersection of critical gaps, high-severity anti-patterns, and high-risk flaky tests. Items are ordered by impact (critical first, then by breadth of affected area).

```markdown
## Prioritized Action Items

{If action items exist:}

Based on current data, these actions would have the highest impact on test suite health:

{Generate action items in this priority order:}

### 1. Add tests for uncovered critical modules
{For each critical-priority gap with hasTest === false:}
- **{sourcePath}** — {reason}
  Action: `/bestest generate --target {sourcePath}`
  {Language-aware note: The actual generator is routed by SKILL.md based on config.yaml language field:
    - Python projects → pytest generator (spoke-generate-python.md)
    - Java projects → JUnit 5 generator (spoke-generate-java.md)
    - Go projects → Go generator (spoke-generate-go.md)
    - JS/TS projects → default generator (spoke-generate.md)
  In multi-language monorepos, the language for each module is determined by its path or its local config.yaml.}

### 2. Fix high-severity anti-patterns
{For each anti-pattern with severity === "critical":}
- **{file}:{line}** — {description}
  Pattern: {pattern}

{For each anti-pattern with severity === "high":}
- **{file}:{line}** — {description}
  Pattern: {pattern}

### 3. Stabilize flaky tests
{For each flaky test with aggregateRisk === "high":}
- **{path} > {name}** — {signals joined by comma}
  Risk: high | Seen in {occurrences.length} scan(s)
  Action: `/bestest fix --flaky {path}`

### 4. Improve coverage for under-tested modules
{For each high-priority gap with hasTest === true but coverage < target:}
- **{sourcePath}** — {coverage}% coverage (target: {target}%)
  Action: `/bestest generate --target {sourcePath}`
  {Language-aware command routing:}
  {  Python: `/bestest generate --target {path}` (uses pytest generator)}
  {  Java: `/bestest generate --target {path}` (uses JUnit 5 generator)}
  {  Go: `/bestest generate --target {path}` (uses Go generator)}

### 5. Address medium-priority gaps
{Summarize medium-priority gaps by count:}
- {mediumCount} medium-priority files need coverage improvement
  Action: `/bestest coverage --module <name>` for per-module details

{If no action items:}

No critical action items. The test suite is healthy:
- All coverage targets met
- No critical or high anti-patterns
- No high-risk flaky tests
- No critical coverage gaps

Continue monitoring with regular /bestest scan and /bestest run executions.
```

Each action item includes a suggested command the developer can run to address it.

### Section 8 — Run History

A compact table of recent run results for quick reference. Present when run reports exist.

```markdown
## Run History

{If isMultiLanguage, include Language column:}

| Date | Language | Suite | Tests | Passed | Failed | Duration | Coverage |
|------|----------|-------|-------|--------|--------|----------|----------|
| Jul 15 14:30 | 📦 JS/TS | all | 142 | 139 | 3 | 5.1s | 82.7% |
| Jul 15 14:28 | 🐍 Python | all | 67 | 65 | 2 | 3.2s | 72.0% |
| Jul 12 10:15 | ☕ Java | unit | 45 | 44 | 1 | 8.5s | 85.0% |

{If single-language, omit Language column — table format unchanged:}

| Date | Suite | Tests | Passed | Failed | Duration | Coverage |
|------|-------|-------|--------|--------|----------|----------|
| Jul 15 14:30 | all | 142 | 139 | 3 | 5.1s | 82.7% |
| Jul 12 10:15 | unit | 98 | 97 | 1 | 2.3s | 80.1% |
| Jul 10 09:00 | all | 138 | 130 | 8 | 4.8s | 78.2% |

{If no run reports:}
No run history available. Run /bestest run to capture test execution data.
```

Limited to the 10 most recent runs, sorted newest first.

---

## Phase 4 — Write Artifacts

Write the generated markdown report to disk, print a console summary, and update config state.

### Execution Steps

1. **Generate the report timestamp** — Create a compact ISO 8601 timestamp for the filename:

   ```
   timestamp = currentDateTime formatted as YYYYMMDDTHHmmssZ
   ```

2. **Write markdown report** — Write the assembled markdown content to `.bestest/reports/report-<timestamp>.md`:

   ```
   Ensure .bestest/reports/ directory exists (mkdir -p .bestest/reports).
   Write the full markdown content to .bestest/reports/report-{timestamp}.md.
   Never overwrite or delete existing reports. All prior reports are preserved.
   If a report with the same timestamp exists (extremely unlikely), append a -2 suffix.
   ```

3. **Update config state** — Write the report timestamp to `.bestest/config.yaml`:

   ```yaml
   state:
     last_report: "<ISO 8601 timestamp>"
   ```

   Read the existing config, update only the `state.last_report` field, and write back. Preserve all other config fields exactly. Do not modify `state.last_run`, `state.last_scan`, `state.last_generate`, or any other field.

   If the `state.last_report` field does not yet exist in config.yaml, add it:

   ```yaml
   state:
     last_scan: <preserve existing>
     last_generate: <preserve existing>
     last_run: <preserve existing>
     last_report: "<new timestamp>"    # Add this line
     version: <preserve existing>
   ```

4. **Print console summary** — Display a human-readable summary of the generated report:

   ```
   ## bestest report generated

   ### Report Details
   - Written to: .bestest/reports/report-{timestamp}.md
   - Data sources: {R} run report(s), {S} scan report(s)
   - Report mode: {full|scan-only|run-only}
   - Language: {language from config, or "multi-language ({list})" if isMultiLanguage}

   ### Key Findings
   - **Pass rate**: {passRate}% ({latest.summary.passed}/{latest.summary.totalTests} tests)
   - **Coverage**: {lines.pct}% lines ({MET ✅ / NOT MET ❌} target of {target}%)
   - **Flaky tests**: {flakyCount} detected
   - **Anti-patterns**: {antiPatternCount} found ({criticalCount} critical)
   - **Critical gaps**: {criticalGapCount} uncovered files

   ### Pass/Fail Trend
   {If trend data available:}
   - Latest: {passRate}% | Previous: {prevPassRate}% | Change: {arrow} {delta}%
   {If only one data point:}
   - Only one run available — no trend comparison yet

   ### Top Action Items
   {List top 3 action items from Phase 3 Section 7, truncated to 80 chars each}
   1. {action item 1}
   2. {action item 2}
   3. {action item 3}

   ### Next Steps
   - Review the full report: .bestest/reports/report-{timestamp}.md
   {If critical gaps exist:}
   - Address critical gaps: /bestest generate --critical
   {If anti-patterns exist:}
   - Fix anti-patterns: /bestest fix
   {If flaky tests exist:}
   - Stabilize flaky tests: /bestest fix --flaky
   {If all healthy:}
   - Continue monitoring: /bestest scan && /bestest report
   ```

### Output

| Artifact | Location | Purpose |
|----------|----------|---------|
| Markdown report | `.bestest/reports/report-<timestamp>.md` | Human-readable test quality report with all sections |
| Updated config state | `.bestest/config.yaml` | `state.last_report` set to report timestamp |
| Console summary | Terminal | Key findings, trends, and next steps |

---

## Error Handling

### 1. No data sources at all

**Trigger**: Pre-Flight Check 2 finds no `run-*.json` and no `scan-*.json` files in `.bestest/reports/`.

**Response**:
```
Print: "No report data found in .bestest/reports/."
Print: "The report command aggregates data from test runs and scans."
Print: "Generate data first by running:"
Print: "  /bestest run --coverage    — Execute tests with coverage"
Print: "  /bestest scan              — Full quality audit"
Print: "After generating data, re-run /bestest report."
```
Exit. No report is written.

### 2. Only scan data available (no run data)

**Trigger**: Scan reports exist but no run reports in `.bestest/reports/`.

**Response**:
```
Print: "Report mode: scan-only — no run history available."
Print: "The following sections will be included:"
Print: "  ✅ Summary, Coverage Heatmap, Flaky Test Trends, Anti-Patterns, Uncovered Critical Paths, Action Items"
Print: "  ❌ Pass/Fail Trends, Duration Trends, Run History"
Print: ""
Print: "Run /bestest run --coverage to enable full report mode with trend analysis."
```
Continue. Generate report in `scan-only` mode. Sections requiring run data show "N/A — run /bestest run for trend data" or are omitted entirely.

### 3. Only run data available (no scan data)

**Trigger**: Run reports exist but no scan reports in `.bestest/reports/`.

**Response**:
```
Print: "Report mode: run-only — no scan data available."
Print: "The following sections will be included:"
Print: "  ✅ Summary, Pass/Fail Trends, Coverage History, Duration Trends, Run History"
Print: "  ❌ Flaky Test Trends, Anti-Pattern Distribution, Uncovered Critical Paths"
Print: ""
Print: "Run /bestest scan to enable full report mode with anti-pattern and gap analysis."
```
Continue. Generate report in `run-only` mode. Sections requiring scan data show "N/A — run /bestest scan for this analysis" or are omitted entirely.

### 4. Corrupted JSON files

**Trigger**: Phase 1 encounters a JSON file in `.bestest/reports/` that cannot be parsed.

**Response**:
```
Print: "Warning: Skipping corrupted report file: {filename}"
Print: "The file contains invalid JSON and cannot be processed."
Print: "Other valid reports will be used. To replace this file:"
Print: "  /bestest run    (for run reports)"
Print: "  /bestest scan   (for scan reports)"
```
Skip the file. Continue processing valid files. If the corrupted file was the only data source, fall back to Error Handling scenario 1 (no data sources).

Log the corrupted filename for the report's metadata section so the user knows which files were skipped.

### 5. Empty reports directory

**Trigger**: `.bestest/reports/` directory exists but contains no `run-*.json` or `scan-*.json` files. May contain other files (e.g., raw framework output, coverage HTML).

**Response**:
```
Print: "The .bestest/reports/ directory exists but contains no run or scan reports."
Print: "Found {otherFileCount} other file(s), but none matching run-*.json or scan-*.json."
Print: "Generate data first:"
Print: "  /bestest run --coverage    — Execute tests and save results"
Print: "  /bestest scan              — Run quality analysis"
```
Exit. No report is written.

### 6. Config state.last_report field missing

**Trigger**: Phase 4 Step 3 attempts to update `state.last_report` in `config.yaml` but the field does not exist.

**Response**:
```
Read existing config.yaml.
Locate the state: section.
If state: section exists:
  Add last_report field after existing fields.
If state: section does not exist:
  Create state: section with all fields from config-schema.md defaults.
  Preserve any existing state fields (last_scan, last_run, etc.).
Write updated config.yaml.
Print: "config.yaml updated: state.last_report field added."
```
This is a non-fatal condition. The report is still written successfully.

### 7. No coverage data in any source

**Trigger**: All run reports have `coverage.collected === false` and all scan reports have zeroed coverage fields.

**Response**:
```
Print: "No coverage data found in any source."
Print: "Coverage sections will show aggregate metrics only (no per-file heatmap)."
Print: "To enable coverage collection:"
Print: "  /bestest config set coverage.enabled true"
Print: "  /bestest run --coverage"
```
Continue. Coverage-related sections fall back to the "no per-file data" variant. The summary section shows "Coverage: N/A" for line coverage. The Coverage History and Heatmap sections are replaced with guidance on enabling coverage.

### 8. Very large data sets

**Trigger**: More than 50 run reports or 20 scan reports found in `.bestest/reports/`.

**Response**:
```
Print: "Large data set detected: {R} run reports, {S} scan reports."
Print: "Report generation may take a moment. For faster results:"
Print: "  Archive older reports to a backup directory"
Print: "  Use --since <date> to limit the time range (future enhancement)"
```
Continue with full processing. For the markdown report:
- Pass/Fail Trends: show only the last 20 comparisons
- Coverage History: show only the last 20 data points
- Flaky Test History: limit to top 30 by risk/occurrence
- Anti-Pattern Distribution: show all patterns but limit file lists to top 5 per pattern
- Run History: show only the last 10 runs

### 9. Mixed-language monorepo with incomplete language data

**Trigger**: `isMultiLanguage` is true but some run reports lack the `language` field (pre-multi-language bestest versions), or scan reports don't include language metadata.

**Response**:
```
Print: "Multi-language project detected: {languages}"
Print: "Note: {count} report(s) have no language field and will be grouped as 'unknown'."
Print: "Re-run /bestest run with the latest bestest version to tag all reports with language."
```
Continue. Reports without a language field are grouped under "unknown" in language-specific sections. The overall aggregate metrics include all reports regardless of language tagging. Unknown-language entries do not appear in per-language breakdowns but are included in the totals.

### 10. Single language config with multi-language reports

**Trigger**: `config.yaml` specifies a single language but run reports contain multiple different language values.

**Response**:
```
Print: "Config specifies language: {configLanguage}, but reports contain: {detectedLanguages}."
Print: "This may indicate a monorepo with multiple language targets."
Print: "Report will include per-language breakdowns for all detected languages."
```
Continue. Use the actual detected languages from the reports rather than the config value for `isMultiLanguage` determination. The report header shows "multi-language ({list})" instead of the config value.

---

## Output

After successful completion, the following artifacts exist:

| Artifact | Location | Purpose |
|----------|----------|---------|
| Markdown report | `.bestest/reports/report-<timestamp>.md` | Complete human-readable test quality report |
| Updated config state | `.bestest/config.yaml` | `state.last_report` set to report generation timestamp |
| Console summary | Terminal | Key findings, top action items, and next steps |
| Prior reports preserved | `.bestest/reports/` | All previous report-*.md files retained for historical comparison |

The markdown report is self-contained — it includes all data and context needed to understand the test suite's current state without reading the underlying JSON files. Prior markdown reports are never deleted or overwritten.

---

## Metrics Update

This spoke writes to `.bestest/state/metrics.json` following the shared metrics-update protocol defined in `references/metrics-schema.md`.

Before reading metrics.json, acquire the concurrency lock per `references/pre-flight-protocol.md` → Concurrency Lock Protocol. The lock must be held for the entire read-modify-write cycle (Steps 0–8). If the lock cannot be acquired, log a warning and proceed with a best-effort write.

### Sections Updated

`activity`

### Field Mapping

| Field | Source | Update Rule |
|-------|--------|-------------|
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
  "spoke": "spoke-report",
  "action": "report",
  "summary": "<human-readable one-line summary>"
}
```

### Graceful Degradation

- **File missing:** Treated as first-time creation. Write this spoke's section with defaults for all others.
- **Parse failure:** Log warning, recreate with defaults + current spoke's data. **Never abort the spoke** — metrics are observability, not a gate.
- **schemaVersion mismatch (MAJOR):** Log warning, attempt to read known fields, write back with current schema version.
- **schemaVersion mismatch (MINOR):** Proceed normally. Unrecognized fields are preserved (pass-through).



## Downstream Reference

### Terminal Spoke

The report command is a **terminal spoke**: no other bestest command consumes its output. The markdown report is designed exclusively for human consumption — developers reading it in a text editor, Markdown viewer, or CI pipeline artifact viewer.

### Input Data Contracts

The report spoke reads data from two sources, each with a defined schema:

#### Run Reports (`run-*.json`)

Source: `references/spoke-run.md` — run-results.json shape

| Field Used | Report Section | Purpose |
|-----------|---------------|---------|
| `summary.totalTests` | Summary, Pass/Fail Trends | Test count tracking |
| `summary.passed` | Summary, Pass/Fail Trends | Pass rate computation |
| `summary.failed` | Summary, Pass/Fail Trends | Failure tracking |
| `summary.skipped` | Summary | Skipped test count |
| `coverage.lines.pct` | Summary, Coverage History, Heatmap | Line coverage percentage |
| `coverage.branches.pct` | Coverage History | Branch coverage percentage |
| `coverage.functions.pct` | Coverage History | Function coverage percentage |
| `coverage.statements.pct` | Coverage History | Statement coverage percentage |
| `execution.durationMs` | Duration Trends, Run History | Execution time tracking |
| `suiteFilter` | Run History | Filter context for each run |
| `framework.name` | Report Header | Framework identification |
| `framework.version` | Report Header | Version tracking |
| `language` | Report Header, Coverage Heatmap, Coverage History, Run History, Pass/Fail Trends | Language detection for multi-language breakdown |
| `errors[]` | Summary | Failure categorization |
| `timestamp` | All trend sections | Chronological ordering |

#### Scan Reports (`scan-*.json`)

Source: `references/scan-report-schema.md`

| Field Used | Report Section | Purpose |
|-----------|---------------|---------|
| `summary.totalTests` | Summary | Total test count |
| `summary.passed` | Summary | Pass count |
| `summary.failed` | Summary | Fail count |
| `coverage.*` | Summary, Coverage History, Heatmap | Coverage metrics |
| `antiPatterns[]` | Anti-Pattern Distribution, Action Items | Pattern detection results |
| `flakyTests[]` | Flaky Test Trends, Action Items | Flaky test identification |
| `gaps[]` | Uncovered Critical Paths, Action Items | Coverage gap analysis |
| `testInventory[]` | Coverage Heatmap | Per-file test status |
| `timestamp` | All trend sections | Chronological ordering |

### Report Format Stability

The markdown report format follows these conventions for users who parse it with scripts:

1. **Section headers are stable** — each section uses a fixed `## Title` that will not change between versions.
2. **Tables use standard markdown** — pipe-delimited with header separators. Suitable for parsing with markdown table libraries.
3. **Emoji indicators are documented** — 🟢 🟡 🔴 ⬛ have fixed meanings (see Coverage Heatmap legend).
4. **The "N/A" marker** — when data is unavailable, sections show "N/A" with a suggestion command. Scripts can detect these strings.
5. **Version changes** — any future changes to report structure will be noted in a `<!-- report-format: 1.0 -->` comment at the top of the generated markdown.

However, the primary audience is human. If you need machine-readable output, prefer the underlying JSON files (`run-*.json`, `scan-*.json`) over parsing the markdown report.

### Config State Contract

The report spoke writes one field to `config.yaml`:

| Field | Type | Written By | Description |
|-------|------|-----------|-------------|
| `state.last_report` | string or null | Report spoke | ISO 8601 timestamp of last report generation |

This field is added by the report spoke and is not present in the initial config created by `init`. Phase 4 Step 3 handles the field's absence gracefully (see Error Handling scenario 6).
