# /bestest status

## Purpose

Display a concise summary of the project's current test health. The `status` command aggregates data from `.bestest/config.yaml`, scan reports, run reports, and doctor reports to present coverage, last activity, flaky tests, CI status, and an overall health score in a single view.

Use `/bestest status` for a quick health check without running a full `scan` or `doctor` — it reads existing state and reports.

## Prerequisites

- `.bestest/` directory must exist — if missing, suggest the user run `/bestest init` first
- `.bestest/config.yaml` must be present and valid — if missing, suggest `/bestest init`
- At least one scan or run report should exist for meaningful data — if none exist, status displays config-only information with a recommendation to run `scan`

## Pre-Flight Checks

### 1. Check for `.bestest/` with valid config

```
If .bestest/ does not exist:
  Print: "No .bestest/ directory found. Run /bestest init first to set up testing infrastructure."
  Exit. No status displayed.

If .bestest/config.yaml does not exist:
  Print: ".bestest/config.yaml is missing. Run /bestest init to generate a config file."
  Exit.

If .bestest/config.yaml exists but is invalid YAML:
  Print: ".bestest/config.yaml contains invalid YAML and cannot be parsed."
  Print: "Fix with: /bestest config validate"
  Exit.

Parse config and extract: framework, language, coverage.target, coverage.enabled, e2e.enabled, ci.enabled, ci.provider
Set hasConfig = true
```

### 2. Check for StackProfile

```
If .bestest/state/stack-profile.json exists AND is valid JSON:
  Set hasProfile = true
  Extract: languages[], primary framework
Else:
  Set hasProfile = false
```

### 3. Check for scan reports

```
Scan .bestest/reports/ for scan-*.json files.
If found:
  Sort by timestamp descending
  Read most recent scan report
  Extract: timestamp, test_count, source_count, coverage_pct, anti_patterns_count, health_score
  Set hasScanData = true
Else:
  Set hasScanData = false
```

### 4. Check for run reports

```
Scan .bestest/reports/ for run-*.json files.
If found:
  Sort by timestamp descending
  Read most recent run report
  Extract: timestamp, total_tests, passed, failed, skipped, duration_ms
  Set hasRunData = true
Else:
  Set hasRunData = false
```

### 5. Check for doctor reports

```
Scan .bestest/reports/ for doctor-*.json files.
If found:
  Sort by timestamp descending
  Read most recent doctor report
  Extract: timestamp, overall_score, dimensions[]
  Set hasDoctorData = true
Else:
  Set hasDoctorData = false
```

### 6. Check for CI files

```
ciDetected = false

If config.ci.enabled AND config.ci.provider:
  ciDetected = true
  ciProvider = config.ci.provider
Else:
  Check for CI files:
    If .github/workflows/*.yml exists: ciDetected = true, ciProvider = "github-actions"
    If .gitlab-ci.yml exists: ciDetected = true, ciProvider = "gitlab-ci"
    If Jenkinsfile exists: ciDetected = true, ciProvider = "jenkins"
```

---

## Workflow

### Step 1: Display header

```
─── bestest status ───
```

### Step 2: Display project configuration

```
Project:     {project directory name}
Framework:   {config.framework}
Language:    {config.language}
Coverage:    {config.coverage.target}% target ({config.coverage.provider})
E2E:         {config.e2e.enabled ? config.e2e.framework : 'disabled'}
CI:          {ciDetected ? ciProvider : 'not configured'}
```

### Step 3: Display coverage status

```
─── Coverage ───
```

If `hasScanData`:
```
  Latest coverage:  {scan.coverage_pct}%
  Target:           {config.coverage.target}%
  Status:           {coverage_pct >= target ? '✓ On target' : '⚠ Below target (gap: {target - coverage_pct}%)'}
  Source files:     {scan.source_count}
  Test files:       {scan.test_count}
  Last scan:        {scan.timestamp}
```

If NOT `hasScanData`:
```
  No scan data available.
  Run /bestest scan to analyze coverage.
```

### Step 4: Display last run results

```
─── Last Run ───
```

If `hasRunData`:
```
  Total:    {run.total_tests}
  Passed:   {run.passed}  ✓
  Failed:   {run.failed}  {run.failed > 0 ? '✗' : ''}
  Skipped:  {run.skipped}
  Duration: {run.duration_ms / 1000}s
  When:     {run.timestamp}
```

If NOT `hasRunData`:
```
  No run data available.
  Run /bestest run to execute tests and capture results.
```

### Step 5: Display flaky test status

```
─── Flaky Tests ───
```

If `hasScanData` AND `scan.anti_patterns_count` exists:
```
  Anti-patterns detected: {scan.anti_patterns_count}
```

If `hasRunData` AND `run.flaky_tests` exists:
```
  Flaky tests detected:   {run.flaky_tests.length}
  For each flaky test:
    - {test_name}: {failure_rate}% failure rate
```

If no flaky data:
```
  No flaky test data available.
  Run /bestest scan to detect flaky tests, or /bestest run to collect execution data.
```

### Step 6: Display CI status

```
─── CI Integration ───
```

If `ciDetected`:
```
  Provider:       {ciProvider}
  Pipeline:       {detected pipeline file path}
  Coverage gate:  {config.coverage.target}%
  Status:         Configured
```

If `hasConfig` AND config.ci.enabled:
```
  (CI configured via config.yaml)
```

If NOT `ciDetected`:
```
  No CI pipeline detected.
  Run /bestest ci to generate a CI pipeline.
```

### Step 7: Display overall health score

```
─── Health Score ───
```

If `hasDoctorData`:
```
  Overall:    {doctor.overall_score}/100
  Dimensions:
    For each dimension:
      {icon} {name}: {score}/100
  Last check: {doctor.timestamp}
```

Else if `hasScanData`:
```
  Estimated:  {scan.health_score}/100 (from last scan)
  Run /bestest doctor for a full health check.
```

Else:
```
  No health data available.
  Run /bestest doctor for a comprehensive health check.
```

### Step 8: Display activity timeline

```
─── Recent Activity ───
```

Collect timestamps from all available data sources and display in reverse chronological order:

```
  {timestamp}  scan     → {test_count} tests, {coverage_pct}% coverage
  {timestamp}  run      → {passed}/{total} passed, {duration_ms/1000}s
  {timestamp}  doctor   → score {overall_score}/100
  {timestamp}  generate → {files_generated} tests generated
  {timestamp}  fix      → {tests_fixed} tests fixed
```

If no activity:
```
  No activity recorded yet.
  Run /bestest scan to start.
```

### Step 9: Display recommendations

Based on the collected data, display actionable next steps:

```
─── Recommendations ───
```

Logic for recommendations:

```
If NOT hasScanData:
  Print: "→ Run /bestest scan to analyze your test suite"

If hasScanData AND coverage_pct < coverage.target:
  Print: "→ Run /bestest generate to increase coverage (gap: {target - coverage_pct}%)"

If hasRunData AND run.failed > 0:
  Print: "→ Run /bestest fix to resolve {run.failed} failing tests"

If NOT ciDetected:
  Print: "→ Run /bestest ci to set up CI integration"

If NOT hasDoctorData:
  Print: "→ Run /bestest doctor for a full infrastructure health check"

If hasDoctorData AND doctor.overall_score < 70:
  Print: "→ Health score is low ({score}/100). Run /bestest doctor for detailed recommendations."

If all checks pass:
  Print: "✓ All systems healthy. No immediate actions needed."
```

### Step 10: Display footer

```
─── Quick Commands ───

  /bestest scan       → Deep audit of test state
  /bestest run        → Execute test suite
  /bestest doctor     → Full health check
  /bestest coverage   → Coverage gap analysis
  /bestest help       → See all commands
```

---

## Error Handling

### 1. No `.bestest/` directory

**Trigger**: Pre-Flight Check 1 finds `.bestest/` does not exist.

**Response**:
```
❌ No .bestest/ directory found.
   Run /bestest init first to set up testing infrastructure.
```
Exit. No status displayed.

### 2. Missing or invalid config.yaml

**Trigger**: `.bestest/config.yaml` is missing or contains invalid YAML.

**Response**:
```
❌ .bestest/config.yaml is missing or invalid.
   Run /bestest init to generate a config file, or /bestest config validate to check for errors.
```
Exit. No status displayed.

### 3. Corrupted report files

**Trigger**: A scan or run report exists but contains invalid JSON.

**Response**:
```
Warning: Could not parse {report filename}. Skipping.
```
Continue with remaining data sources. Set the corresponding `hasData` flag to false.

### 4. Corrupted StackProfile

**Trigger**: `.bestest/state/stack-profile.json` exists but is invalid JSON.

**Response**:
```
Warning: stack-profile.json could not be parsed. Omitting stack context.
```
Continue with `hasProfile = false`.

### 5. No reports available

**Trigger**: No scan, run, or doctor reports exist in `.bestest/reports/`.

**Response**:
```
─── Status ───

  Configuration loaded from .bestest/config.yaml
  No scan or run data available yet.

  Run these commands to populate status data:
    /bestest scan     → Analyze test suite
    /bestest run      → Execute tests
    /bestest doctor   → Health check
```
Continue with config-only display. Do not exit — partial status is still useful.

---

## Downstream Reference

### Input Data Contracts

| Source | Fields Used | Purpose |
|--------|------------|---------|
| `config.yaml` | `framework`, `language`, `coverage.target`, `coverage.enabled`, `e2e.*`, `ci.*` | Project configuration display |
| `stack-profile.json` | `languages[]` | Stack context |
| `reports/scan-*.json` | `timestamp`, `test_count`, `source_count`, `coverage_pct`, `anti_patterns_count`, `health_score` | Coverage and scan status |
| `reports/run-*.json` | `timestamp`, `total_tests`, `passed`, `failed`, `skipped`, `duration_ms`, `flaky_tests` | Run results display |
| `reports/doctor-*.json` | `timestamp`, `overall_score`, `dimensions[]` | Health score display |
| CI files | File existence check | CI status display |

### Output Data Contracts

The status spoke produces only console output — no files are written.

### Spoke Relationships

```
spoke-status → reads config, scan reports, run reports, doctor reports, CI files
spoke-init → creates .bestest/ and config.yaml that status uses
spoke-scan → creates scan reports that status reads
spoke-run → creates run reports that status reads
spoke-doctor → creates doctor reports that status reads
spoke-ci → creates CI pipeline files that status detects
spoke-help → provides command reference (cross-linked)
spoke-explain → provides detailed explanations (complementary to status summary)
```

### See Also

- `references/config-schema.md` — Field definitions for config display
- `references/dot-bestest-schema.md` — Report file formats and locations
- `references/scan-report-schema.md` — Scan report JSON schema
