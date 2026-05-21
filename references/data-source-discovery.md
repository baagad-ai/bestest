Part of **pre-flight-protocol.md** (see references/pre-flight-protocol.md). Shared discovery pattern used by fix, coverage, report, doctor, and status spokes.

## Shared Data Source Discovery

Multiple spokes need to find the most recent execution results to operate. This shared discovery pattern ensures consistent behavior across all spokes that consume test results. It replaces ad-hoc report lookup with a single, ordered priority chain.

### Priority Chain for Run Result Discovery

When a spoke needs test execution data (pass/fail status, per-test error messages, coverage metrics), it follows this priority chain:

```
1. Most recent run-*.json in .bestest/reports/
   - Primary source — contains full per-test detail in run-results.json schema
   - Produced by: spoke-run, spoke-scan (as companion artifact)

2. Most recent scan-*.json in .bestest/reports/
   - Fallback source — contains testInventory[] with per-file status, summary with pass/fail counts
   - When using scan as source: map testInventory[].status to per-file outcomes
   - Missing: individual test case error messages (only file-level status available)
   - Missing: execution timing per test case (only aggregate coverage)

3. Language-specific raw coverage artifacts (framework-known from config.yaml):
   - Python: .bestest/reports/coverage.json (coverage.py)
   - Java (Gradle): build/reports/jacoco/test/jacocoTestReport.xml
   - Java (Maven): target/site/jacoco/jacoco.xml
   - Go: .bestest/reports/go-coverage.out
   - Last resort — coverage data only, no test results

4. None found → exit with actionable message listing which commands produce the needed artifacts
```

### Implementation Pattern

Spokes that consume test results should call this discovery logic in their pre-flight phase:

```
// Shared discovery — used by fix, coverage, report, doctor, status
function findLatestRunData():
  reports_dir = ".bestest/reports/"

  // Priority 1: run report
  run_reports = glob(reports_dir + "run-*.json").sort_descending()
  if run_reports.length > 0:
    report = parse_json(run_reports[0])
    if report.schemaVersion MAJOR matches expected:
      return { source: "run-report", file: run_reports[0], data: report }

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

  // Priority 3: raw coverage (framework-specific)
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
| fix | run → scan → exit | Uses scan report to identify failed files; warns about missing per-test errors |
| coverage | run → scan → raw → exit | Full chain per spoke-coverage pre-flight |
| doctor | run → scan → partial | Degrades gracefully with missing data sources |
| report | run → scan → partial | Aggregates from all available sources |
| status | run → scan → doctor → config | Displays whatever is available |

---

