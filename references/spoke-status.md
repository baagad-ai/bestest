# /bestest status

## Purpose

Display a concise summary of the project's current test health. The `status` command aggregates data from `.bestest/config.yaml`, scan reports, run reports, and doctor reports to present coverage, last activity, flaky tests, CI status, and an overall health score in a single view.

Use `/bestest status` for a quick health check without running a full `scan` or `doctor` — it reads existing state and reports.

## Prerequisites

- `.bestest/` directory must exist — if missing, suggest the user run `/bestest init` first
- `.bestest/config.yaml` must be present and valid — if missing, suggest `/bestest init`
- At least one scan or run report should exist for meaningful data — if none exist, status displays config-only information with a recommendation to run `scan`

## Pre-Flight Checks

> See **references/pre-flight-protocol.md** for the standard 3-step `.bestest/` validation pattern and spoke-specific variants.

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
Preferred (CLI): if python3 is available:
  python3 <skill-dir>/scripts/bestest-cli.py report list --kind scan --latest
  → { latest: { file, data } | null }
  If latest is non-null, extract fields from latest.data (see below).

Fallback (manual): Scan .bestest/reports/ for scan-*.json files.
If found:
  Sort by timestamp descending
  Read most recent scan report
Extract: timestamp, summary.totalTests, summary.totalTestFiles,
         coverage.lines.pct, coverage.branches.pct,
         antiPatterns.length, flakyTests[]
Set hasScanData = true
Else:
  Set hasScanData = false
```

> **Note:** Scan reports contain no top-level `health_score`. Health is reported by the doctor spoke (`healthScore`). For coverage display, use `coverage.lines.pct` (fall back to `coverage.statements.pct` if lines is null).

### 4. Check for run reports

```
Preferred (CLI): if python3 is available:
  python3 <skill-dir>/scripts/bestest-cli.py report list --kind run --latest
  → { latest: { file, data } | null }
  Exclude latest.data if it is a companion report (suiteFilter: "generated" or companionTo present)
  — these are partial verification runs from generate/scan, not full-suite results.

Fallback (manual): Scan .bestest/reports/ for run-*.json files.
If found:
  Sort by timestamp descending
  Read most recent NON-companion run report
Extract: timestamp, summary.totalTests, summary.passed, summary.failed,
         summary.skipped, execution.durationMs
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
  Extract: timestamp, healthScore, status, dimensions (object keyed by
           dimension-id, each with label, score, weight, status, note)
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
  Latest coverage:  {scan.coverage.lines.pct}%
  Target:           {config.coverage.target}%
  Status:           {scan.coverage.lines.pct >= target ? '✓ On target' : '⚠ Below target (gap: {target - scan.coverage.lines.pct}%)'}
  Source files:     {scan.summary.totalTestFiles}
  Test files:       {scan.summary.totalTests}
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
  Total:    {run.summary.totalTests}
  Passed:   {run.summary.passed}  ✓
  Failed:   {run.summary.failed}  {run.summary.failed > 0 ? '✗' : ''}
  Skipped:  {run.summary.skipped}
  Duration: {run.execution.durationMs / 1000}s
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

If `hasScanData` AND `scan.antiPatterns` exists:
```
  Anti-patterns detected: {scan.antiPatterns.length}
```

If `hasScanData` AND `scan.flakyTests` is a non-empty array:
```
  Flaky tests detected:   {scan.flakyTests.length}
  For each flaky test:
    - {test_name}: risk {riskLevel} (signals: {signals joined by ', '})
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
  Overall:    {doctor.healthScore}/100 ({doctor.status})
  Dimensions:
    For each dimension in doctor.dimensions (object keyed by id):
      {icon} {dimension.label}: {dimension.score}/100
  Last check: {doctor.timestamp}
```

Else if `hasScanData`:
```
  No doctor data yet. Run /bestest doctor for a full health check.
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
  {timestamp}  scan     → {summary.totalTests} tests, {coverage.lines.pct}% coverage
  {timestamp}  run      → {summary.passed}/{summary.totalTests} passed, {execution.durationMs/1000}s
  {timestamp}  doctor   → score {healthScore}/100
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

If hasScanData AND coverage.lines.pct < coverage.target:
  Print: "→ Run /bestest generate to increase coverage (gap: {target - coverage.lines.pct}%)"

If hasRunData AND run.summary.failed > 0:
  Print: "→ Run /bestest fix to resolve {run.summary.failed} failing tests"

If NOT ciDetected:
  Print: "→ Run /bestest ci to set up CI integration"

If NOT hasDoctorData:
  Print: "→ Run /bestest doctor for a full infrastructure health check"

If hasDoctorData AND doctor.healthScore < 70:
  Print: "→ Health score is low ({healthScore}/100). Run /bestest doctor for detailed recommendations."

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
| `reports/scan-*.json` | `timestamp`, `summary.totalTests`, `summary.totalTestFiles`, `coverage.lines.pct`, `antiPatterns`, `flakyTests` | Coverage and scan status |
| `reports/run-*.json` | `timestamp`, `summary.totalTests`, `summary.passed`, `summary.failed`, `summary.skipped`, `execution.durationMs` | Run results display (non-companion runs only) |
| `reports/doctor-*.json` | `timestamp`, `healthScore`, `status`, `dimensions` | Health score display |
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
