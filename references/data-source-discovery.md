Part of **pre-flight-protocol.md** (see references/pre-flight-protocol.md). Shared discovery pattern used by fix, coverage, report, doctor, and status spokes.

## Shared Data Source Discovery

Multiple spokes need to find the most recent execution results to operate. This shared discovery pattern ensures consistent behavior across all spokes that consume test results. It replaces ad-hoc report lookup with a single, ordered priority chain.

### Companion Run Reports

`spoke-run` writes full-suite run reports. In addition, `spoke-generate` (all 4 languages) and `spoke-scan` write **companion run reports** — partial verification runs. These are distinguishable by two fields:

| Field | Full-suite run (spoke-run) | Companion (generate / scan) |
|-------|---------------------------|------------------------------|
| `suiteFilter` | `unit`, `integration`, `e2e`, `all`, or `affected` | `"generated"` (generate) or `"all"` (scan companion) |
| `companionTo` | absent | `"generate"` or `"scan-<timestamp>.json"` |

**Consumers MUST filter companion reports out of "latest run" selection by default.** A generate companion covers only the newly generated tests — treating it as the full-suite baseline corrupts fix diagnosis (empty failure set), coverage trends (partial snapshot), and flaky detection. Consumers that want to include companions for trend context (e.g., report spoke) must label them explicitly in output rather than merging them silently with full-suite runs.

### Priority Chain for Run Result Discovery

When a spoke needs test execution data (pass/fail status, per-test error messages, coverage metrics), it follows this priority chain:

```
1. Most recent NON-companion run-*.json in .bestest/reports/
   - Primary source — contains full per-test detail in run-results.json schema
   - Filter: exclude reports where suiteFilter === "generated" OR companionTo is present
   - Produced by: spoke-run

2. Most recent scan-*.json in .bestest/reports/
   - Fallback source — contains testInventory[] with per-file status, summary with pass/fail counts
   - When using scan as source: map testInventory[].status to per-file outcomes
   - Missing: individual test case error messages (only file-level status available)
   - Missing: execution timing per test case (only aggregate coverage)

3. Most recent companion run report (suiteFilter === "generated")
   - Last-resort run source — partial results only, warn the user that coverage/failures reflect generated tests only
   - Produced by: spoke-generate (all 4 languages)

4. Language-specific raw coverage artifacts (framework-known from config.yaml):
   - Python: .bestest/reports/coverage.json (coverage.py)
   - Java (Gradle): build/reports/jacoco/test/jacocoTestReport.xml
   - Java (Maven): target/site/jacoco/jacoco.xml
   - Go: .bestest/reports/go-coverage.out
   - Last resort — coverage data only, no test results

5. None found → exit with actionable message listing which commands produce the needed artifacts
```

### Implementation Pattern

Spokes that consume test results should call this discovery logic in their pre-flight phase:

```
// Shared discovery — used by fix, coverage, report, doctor, status
function findLatestRunData(preferCompanion = false):
  reports_dir = ".bestest/reports/"

  // Priority 1: full-suite run report (exclude companion runs)
  run_reports = glob(reports_dir + "run-*.json").sort_descending()
  full_runs = run_reports.filter(r => !r.hasOwnProperty("companionTo") && r.suiteFilter !== "generated")
  if full_runs.length > 0:
    report = parse_json(full_runs[0])
    if report.schemaVersion MAJOR matches expected:
      return { source: "run-report", file: full_runs[0], data: report }

  // Priority 2: scan report (extract testInventory failures)
  scan_reports = glob(reports_dir + "scan-*.json").sort_descending()
  if scan_reports.length > 0:
    report = parse_json(scan_reports[0])
    if report.schemaVersion MAJOR matches expected:
      failed_files = report.testInventory.filter(t => t.status === "failed" || t.status === "mixed")
      return {
        source: "scan-report",
        file: scan_reports[0],
        data: report,
        warnings: ["Using scan report — individual test case error messages unavailable. Run /bestest run for full detail."]
      }

  // Priority 3: companion run report (partial — generated tests only)
  if preferCompanion:
    companions = run_reports.filter(r => r.suiteFilter === "generated" || r.companionTo === "generate")
    if companions.length > 0:
      report = parse_json(companions[0])
      return {
        source: "run-report-companion",
        file: companions[0],
        data: report,
        warnings: ["Using companion run report — results reflect generated tests only. Run /bestest run for the full suite."]
      }

  // Priority 4: raw coverage (framework-specific)
  framework = read_config().framework
  raw = find_raw_coverage_artifact(framework)
  if raw:
    return { source: "raw-coverage", file: raw, warnings: ["Only coverage data available — no test results."] }

  // Nothing found
  return { source: null }
```

### Spokes Using This Pattern

| Spoke | Priority Chain Used | Fallback Behavior |
|-------|-------------------|-------------------|
| fix | run (non-companion) → scan → companion → exit | Uses scan report to identify failed files; warns about missing per-test errors. `--flaky` mode counts non-companion runs only. |
| coverage | run (non-companion) → scan → raw → exit | Full chain per spoke-coverage pre-flight; ignores generated-only companion coverage |
| doctor | run (non-companion) → scan → partial | Degrades gracefully with missing data sources |
| report | run + scan (all reports, companions labeled) → partial | Aggregates from all available sources; labels companion runs in trends/history |
| status | run (non-companion) → scan → doctor → config | Displays whatever is available |

### Canonical Implementation (CLI)

When `python3` is available, spokes SHOULD delegate the discovery to the CLI rather than hand-rolling the glob/sort/filter logic:

```
python3 <skill-dir>/scripts/bestest-cli.py report latest-full
```

This returns `{ "ok": true, "source": "run-report" | "scan-report" | "run-report-companion" | null, "file": "...", "data": {...} }` — the priority chain above, implemented deterministically (see `references/bestest-cli.md`). If the CLI is unavailable, follow the prose chain above.

---

