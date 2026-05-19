# Pre-Flight Protocol

Shared validation pattern used across all bestest spokes. Every spoke runs pre-flight checks before beginning its core workflow. These checks guard against invalid states and give the user early, actionable feedback rather than failing deep inside a pipeline.

This document is the normative reference. When adding a new spoke or modifying an existing one, the pre-flight section should conform to one of the patterns below.

---

## Standard 3-Step `.bestest/` Validation

Used by: `scan`, `run`, `doctor`, `report`, `coverage`, `fix`, `expand`, `migrate`, `generate`.

This is the baseline validation that most spokes share. It checks three things in order, exiting early on the first failure.

### Step 1 — `.bestest/` directory existence

```
If .bestest/ does not exist:
  Print: "No .bestest/ directory found. Run /bestest init first to set up testing infrastructure."
  Exit.
```

### Step 2 — `config.yaml` presence

```
If .bestest/config.yaml does not exist:
  Print: ".bestest/config.yaml is missing. The config file is required for {command}."
  Print: "Run /bestest init to regenerate it, or restore it from version control."
  Exit.
```

Replace `{command}` with the spoke name (e.g. `scan`, `run`, `doctor`).

### Step 3 — YAML validity

```
If .bestest/config.yaml exists but is invalid YAML:
  Print: ".bestest/config.yaml contains invalid YAML and cannot be parsed."
  Print: "Fix the syntax error and re-run /bestest {command}."
  Exit.
```

If all three pass, parse config.yaml into a structured object and extract the fields the spoke needs.

### Step 4 — `metrics.json` pre-read validation (optional)

Spokes that read `.bestest/state/metrics.json` (scan, run, fix, generate, migrate, doctor, coverage, report, config) must validate it before parsing. This step is optional — spokes that do not read metrics.json can skip it.

```
If the spoke reads metrics.json:
  Attempt to parse .bestest/state/metrics.json.
  If the file does not exist:
    Treated as first-time creation. Spoke writes its section with defaults for all others.
    Continue — do NOT exit.
  If parsing fails (SyntaxError, unexpected token, etc.):
    Log warning: "metrics.json corrupted — recreating with defaults"
    Initialize fresh metrics with schemaVersion "1.0" and default values from references/metrics-schema.md
    Continue with the spoke's own section merge (step 5 of the Update Protocol)
    Do NOT abort the spoke — metrics are observability, not a gate.
  If schemaVersion MAJOR differs:
    Log warning: "metrics.json schema version mismatch: expected 1.x, found {version}"
    Attempt to read known fields, write back with current schema version.
    Continue.
  If schemaVersion MINOR differs or is missing:
    Proceed normally. Unrecognized fields are preserved (pass-through).
```

This graceful degradation ensures that metrics corruption never blocks a spoke from completing its primary work. See `references/metrics-schema.md` → "Graceful Degradation" for the full protocol.

---

## Concurrency Lock Protocol

Used by: all spokes that **write** to `metrics.json` or `config.yaml` (scan, run, fix, generate, migrate, config, init).

When two bestest instances run concurrently — two agent windows, parallel-dispatch workers, or a human and an agent — their read-modify-write cycles can silently overwrite each other's data. This protocol uses advisory file locking to serialize writes without blocking reads.

### Lock File Locations

| Resource | Lock File |
|----------|-----------|
| `.bestest/state/metrics.json` | `.bestest/state/.metrics.lock` |
| `.bestest/config.yaml` | `.bestest/.config.lock` |

Lock files live alongside the resources they protect. They are ephemeral state — add `.bestest/state/.metrics.lock` and `.bestest/.config.lock` to `.gitignore`.

### Primary Strategy: `flock(1)` (Linux / macOS)

`flock` is the preferred locking mechanism. It is atomic, auto-releases on process exit (no stale locks from crashes), and supports a non-blocking timeout.

```bash
# --- Acquire lock, read-modify-write metrics.json, release on exit ---
LOCKFILE=".bestest/state/.metrics.lock"
METRICS=".bestest/state/metrics.json"

# Ensure lock file exists
mkdir -p "$(dirname "$LOCKFILE")"
touch "$LOCKFILE"

# Acquire exclusive lock with 5-second timeout, write inside subshell
(
  if ! flock -s -w 5 200; then
    echo "⚠ [bestest] Could not acquire lock on $LOCKFILE within 5s. Proceeding without lock (best-effort)." >&2
    # Fall through to write anyway — metrics are observability, not gates.
  fi

  # --- Read-modify-write section (locked) ---
  # Read current metrics (or use defaults if missing/corrupt)
  if [ -f "$METRICS" ]; then
    CURRENT=$(cat "$METRICS")
  else
    CURRENT='{"schemaVersion":"1.0"}'
  fi

  # ... merge / update $CURRENT here ...

  # Write back atomically via temp file + mv
  TMPFILE=$(mktemp "$(dirname "$METRICS")/metrics.XXXXXX")
  echo "$CURRENT" > "$TMPFILE"
  mv "$TMPFILE" "$METRICS"
) 200>"$LOCKFILE"
```

Key points:
- The subshell `( ... ) 200>"$LOCKFILE"` redirects fd 200 to the lock file; `flock -s -w 5 200` operates on that fd.
- When the subshell exits (normally or via crash), the kernel closes fd 200 and releases the lock automatically.
- `flock -s` means exclusive (writer) lock. Use `flock -s -s` for shared (reader) locks if needed — but spokes that only read metrics do not need to lock at all.

### Fallback Strategy: `mkdir`-based Lock (NFS / systems without `flock`)

On environments where `flock` is unavailable (some NFS mounts, minimal containers), use `mkdir` which is atomic on all POSIX filesystems:

```bash
# --- mkdir-based lock with retry loop ---
LOCKDIR=".bestest/state/.metrics.lock"
METRICS=".bestest/state/metrics.json"
MAX_ATTEMPTS=3
SLEEP_SEC=2

acquired=false
for i in $(seq 1 $MAX_ATTEMPTS); do
  if mkdir "$LOCKDIR" 2>/dev/null; then
    acquired=true
    break
  fi
  # Stale lock check: if lock dir is older than 60 seconds, force-remove
  if [ -d "$LOCKDIR" ]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCKDIR" 2>/dev/null || stat -c %Y "$LOCKDIR" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt 60 ]; then
      echo "⚠ [bestest] Stale lock detected ($LOCKDIR is ${lock_age}s old). Removing." >&2
      rm -rf "$LOCKDIR"
      # Retry on next iteration
    fi
  fi
  sleep $SLEEP_SEC
done

if [ "$acquired" = false ]; then
  echo "⚠ [bestest] Could not acquire lock on $LOCKDIR after $MAX_ATTEMPTS attempts. Proceeding without lock (best-effort)." >&2
fi

# --- Read-modify-write section ---
if [ -f "$METRICS" ]; then
  CURRENT=$(cat "$METRICS")
else
  CURRENT='{"schemaVersion":"1.0"}'
fi

# ... merge / update $CURRENT here ...

TMPFILE=$(mktemp "$(dirname "$METRICS")/metrics.XXXXXX")
echo "$CURRENT" > "$TMPFILE"
mv "$TMPFILE" "$METRICS"

# --- Release lock ---
if [ "$acquired" = true ]; then
  rm -rf "$LOCKDIR"
fi
```

Note: `mkdir`-based locks require explicit cleanup via `rm -rf`. The stale lock detection (60-second threshold) handles crashed agents that left locks behind.

### Stale Lock Detection

Both strategies handle stale locks:

| Strategy | Stale Lock Handling |
|----------|-------------------|
| `flock` | **Automatic.** The kernel releases the lock when the holding process exits (even on crash). No stale locks possible. |
| `mkdir` | **Manual.** Before each retry, check lock directory age. If older than **60 seconds**, force-remove and re-attempt. This covers crashed agents, killed processes, and orphaned locks. |

The 60-second threshold is conservative — most bestest read-modify-write cycles complete in under 5 seconds. A lock held for over a minute almost certainly comes from a crashed process.

### Ordered Locking Rule (Deadlock Prevention)

When a spoke needs to write to **both** `config.yaml` and `metrics.json` in the same operation, it **must** acquire locks in this order:

1. **Config lock first** (`.bestest/.config.lock`)
2. **Metrics lock second** (`.bestest/state/.metrics.lock`)

This fixed ordering ensures that two concurrent spokes can never deadlock each other by acquiring locks in opposite order.

If a spoke only needs one lock, it acquires only that lock — no ordering concern.

### Lock Acquisition Failure (Best-Effort Fallback)

Locks are advisory, not mandatory. If a lock cannot be acquired after the full timeout/retry cycle, the spoke **proceeds with the write anyway** and emits a visible warning:

```
⚠ [bestest] Could not acquire lock on .bestest/state/.metrics.lock within 5s.
  Proceeding without lock — concurrent writes may cause data loss.
  If this persists, check for stale lock files or other running bestest instances.
```

Rationale: bestest metrics and config are **observability and configuration**, not transactional data. Losing a metrics update is far less harmful than blocking an agent's workflow entirely. The warning ensures the situation is visible for later diagnosis.

### Cross-References

- `references/metrics-schema.md` → "Update Protocol" — the read-modify-write contract that this lock protects.
- `references/pipeline-shared.md` → "Config State Update" — config.yaml update semantics guarded by the config lock.
- `references/schema-contract.md` → version compatibility rules that apply inside locked write sections.

### Integration with Pre-Flight Steps

This lock protocol runs **after** the Standard 3-Step validation (Steps 1–3) and **after** Step 4 (metrics.json pre-read validation). Locking is only needed for the write phase, not for validation reads:

```
1. Run Steps 1–4 (validation — no locking needed)
2. Acquire lock(s) in order (config → metrics) before write phase
3. Perform read-modify-write inside locked section
4. Release lock(s) on completion or error
```

---

## Init-Specific Pattern (Inverse)

Used by: `init`.

Init uses the **inverse** of the standard pattern: `.bestest/` must **not** exist.

### Step 1 — `.bestest/` must NOT exist

```
If .bestest/ exists:
  Print: "A .bestest/ directory already exists. This suggests testing infrastructure has been set up before."
  Print: "Run /bestest doctor to validate your existing setup, or delete .bestest/ to start fresh."
  Exit. No files created or modified.
```

### Step 2 — Project manifest must exist

```
Check for the following files at the project root (in order):
  1. package.json      → JS/TS ecosystem
  2. pyproject.toml    → Python ecosystem (modern)
  3. requirements.txt  → Python ecosystem (classic)
  4. setup.py          → Python ecosystem (legacy)
  5. go.mod            → Go ecosystem
  6. pom.xml           → JVM ecosystem (Maven)
  7. build.gradle / build.gradle.kts → JVM ecosystem (Gradle)

If none found:
  Print: "No supported project manifest found. /bestest init requires a JS/TS, Python, Java, or Go project."
  Print: "Looked for: package.json, pyproject.toml, requirements.txt, setup.py, go.mod, pom.xml, build.gradle"
  Exit.
```

### Step 3 — Git status (informational, non-blocking)

```
If git is initialized:
  If uncommitted changes exist:
    Print: "Warning: You have uncommitted changes. Consider committing or stashing before init."
    Continue — warning only, not a blocker.
Else:
  Print: "Note: No git repository detected. Init will proceed, but version control is recommended."
  Continue.
```

### Step 4 — Version compatibility check

After config.yaml is generated, verify version compatibility:

```
Read the version field from .bestest/config.yaml.
Compare with the current skill version.
If MINOR mismatch:
  Print: "⚠ Version mismatch: config was generated by bestest v{config_version}, current plugin is v{skill_version}."
If no version field:
  Print: "Note: config.yaml has no version field. It may predate version tracking."
```

See `references/schema-contract.md` for the full version policy.

---

## Config-Specific Pattern (Lightweight)

Used by: `config`.

Config needs the standard `.bestest/` validation but with lighter prerequisites — no StackProfile or scan report required.

### Prerequisites

- `.bestest/` directory must exist — if missing, suggest `/bestest init`
- `config.yaml` must be present and valid YAML — if invalid, report the parse error
- `config-schema.md` is the authoritative source for all field definitions
- StackProfile in `.bestest/state/stack-profile.json` provides context for smart defaults (optional)

Config does **not** check for StackProfile, scan reports, or framework installation — it operates on the config file itself.

---

## Generate-Specific Additions

Used by: `generate`, and by language-specific generate spokes (`generate-js`, `generate-py`, `generate-java`, `generate-go`).

Generate extends the standard 3-step pattern with additional checks after the baseline passes.

### Additional Step A — StackProfile check

```
If .bestest/state/stack-profile.json does not exist:
  Print: "Warning: StackProfile not found. Will attempt framework detection from package.json."
  Set framework = detect from package.json devDependencies.
Else:
  Read and parse StackProfile JSON.
  Extract testFrameworks.existing, coverage.provider, monorepo, frontend, languages.
```

### Additional Step B — Confidence gate

```
Confidence gate: See SKILL.md "Confidence Gate (R5)".
The orchestrator checks StackProfile.languages[0].confidence < 0.6 before loading the spoke.
If confidence is below threshold, the user sees:
  "⚠ Low confidence in language detection ({confidence}). Options:"
  "  (a) Proceed with detected language"
  "  (b) Re-run /bestest init for better detection"
  "  (c) Cancel and specify framework manually"
If you reached this spoke, confidence already passed the gate.
```

### Additional Step C — Scan report availability

```
If no scan report exists in .bestest/reports/:
  Print: "Warning: No scan report found. Generation will use filesystem scanning."
  Set mode = "filesystem-scan", gaps = [], testInventory = [].
Else:
  Load most recent scan report. Extract gaps[], testInventory[], configSnapshot.
  Set mode = "scan-guided".
```

### Additional Step D — Schema version validation

```
Validate stack-profile.json schemaVersion ≤ 1.3 and scan-report.json schemaVersion ≤ 1.2.
If MAJOR version differs → error and exit.
If MINOR exceeds expected → warning and continue.
If missing → treat as "1.0" legacy. Continue.
```

See `references/generate/phase1-target-detail.md` for the full validation algorithm.

### Additional Step E — Generation config fields

Parse `generation.*` fields from config.yaml:

| Field | Type | Default | Usage |
|-------|------|---------|-------|
| `generation.quality_threshold` | number | `0.7` | Minimum quality score (0–1). Tests below are flagged. |
| `generation.verify_compilation` | boolean | `true` | Whether Phase 5 (compilation) runs. |
| `generation.verify_pass` | boolean | `true` | Whether Phase 6 (execution) runs. |
| `generation.max_retries` | number | `2` | Maximum fix-and-rerun attempts in Phase 6. |

---

## Scan/Run-Specific Additions

Used by: `scan`, `run`.

After the standard 3-step pattern, these spokes check two more things.

### Additional Step A — StackProfile (warning, non-blocking)

```
If .bestest/state/stack-profile.json does not exist:
  Print: "Warning: StackProfile not found at .bestest/state/stack-profile.json."
  Print: "{command} will continue in config-only mode with reduced analysis depth."
  Print: "Run /bestest init to generate a full StackProfile for richer analysis."
  Set mode = "config-only"
Else:
  Read and parse the StackProfile JSON.
  Set mode = "full"
```

The key difference from generate: StackProfile absence is a **warning** for scan/run (they degrade gracefully), but generate treats it as a significant limitation.

### Additional Step B — Test framework installation check

```
Read config.yaml → framework field.

JavaScript/TypeScript (vitest or jest):
  Check package.json devDependencies for the framework package.
  If not found:
    Print: "Config specifies {framework} but it is not installed."
    Print: "Install it with: npm install --save-dev {framework}"
    Print: "Or run /bestest init to set up dependencies."
    Exit.

Python (pytest):
  Check for pytest in requirements.txt or pyproject.toml dependencies.
  Verify importability: python -c "import pytest"
  If not installed:
    Print: "Config specifies pytest but it is not installed."
    Print: "Install it with: pip install pytest pytest-cov"
    Exit.

Java (junit5):
  Check build.gradle/pom.xml for JUnit 5 dependencies.
  If not found:
    Print: "Config specifies junit5 but dependencies are missing."
    Exit.

Go (go_testing):
  Check that `go test` is available in PATH.
  If not found:
    Print: "Config specifies go_testing but 'go' is not in PATH."
    Exit.
```

---

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

## Pattern Selection Guide

When creating a new spoke, choose the appropriate pre-flight pattern:

| If the spoke... | Use pattern | Why |
|-----------------|-------------|-----|
| Reads config.yaml and requires `.bestest/` to exist | Standard 3-step (+ Step 4 if reading metrics) | Baseline for all operational spokes |
| Creates `.bestest/` | Init-specific (inverse) | Must not overwrite existing setup |
| Only reads/modifies config.yaml | Config-specific (lightweight) | No StackProfile or scan report needed |
| Generates test files | Generate-specific | Needs confidence gate, schema version, scan report |
| Analyzes or executes tests | Scan/Run-specific | Needs framework installation check |
| Consumes test results from other spokes | Standard 3-step + Shared Data Source Discovery | Needs run/scan report to operate |

---

## Error Message Conventions

All pre-flight error messages follow these conventions:

1. **State what was expected** — "No `.bestest/` directory found."
2. **Provide the fix** — "Run `/bestest init` first."
3. **Offer alternatives when relevant** — "Or restore from version control."
4. **Use the spoke name** — Replace `{command}` with the actual spoke name in error messages.
5. **Exit immediately** — Do not continue past a pre-flight failure. Early exit prevents confusing downstream errors.
6. **Warnings don't exit** — Missing StackProfile and scan reports are warnings with graceful degradation, not blockers.
