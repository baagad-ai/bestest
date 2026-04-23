# /bestest doctor

## Purpose

Run a comprehensive 9-dimension health check on the project's testing infrastructure, producing a 0–100 composite score with per-dimension breakdowns and a prioritized remediation list. The doctor command is a **read-only diagnostic aggregator** — it synthesizes data from existing artifacts (run results, scan reports, config, package.json) into a single health assessment. It never modifies source code, test files, or configuration beyond updating `state.last_doctor` in `config.yaml`.

Use `/bestest doctor` after running `scan` and/or `run` to get a quick, actionable health score. The command is designed for developers, tech leads, and CI review — anyone who needs a single number representing test suite health, plus the detail needed to improve it.

Dimensions that lack data sources are **gracefully skipped** (not penalized). CI-related checks show `not_configured` without affecting the score. A minimum of 3 scorable dimensions is required; below that threshold the doctor cannot produce a meaningful score and reports a diagnostic warning instead.

## Prerequisites

- `.bestest/` directory must exist with valid `config.yaml` (run `/bestest init` first)
- **At least one data source** should be present for meaningful results:
  - `run-*.json` files in `.bestest/reports/` (from prior `/bestest run` executions), OR
  - `scan-*.json` files in `.bestest/reports/` (from prior `/bestest scan` executions)
- `package.json` at the project root enriches the framework version dimension for JS/TS projects; for Python/Java/Go the language-specific manifest file is used instead

## Pre-Flight Checks

Run these checks before loading data. They guard against invalid states and give the user early, actionable feedback.

### 1. Check for `.bestest/` with valid config

```
If .bestest/ does not exist:
  Print: "No .bestest/ directory found. Run /bestest init first to set up testing infrastructure."
  Exit. No health check performed.

If .bestest/config.yaml does not exist:
  Print: ".bestest/config.yaml is missing. The config file is required for doctor."
  Print: "Run /bestest init to regenerate it, or restore it from version control."
  Exit.

If .bestest/config.yaml exists but is invalid YAML:
  Print: ".bestest/config.yaml contains invalid YAML and cannot be parsed."
  Print: "Fix the syntax error and re-run /bestest doctor."
  Exit.
```

Parse and extract fields used during health checks:
- `framework` — test framework name for version and config checks
- `language` — primary language (`javascript`, `typescript`, `python`, `java`, `go`). Auto-detected during init.
- `coverage.target` — numeric threshold for coverage trend comparison (default: `80` if absent)
- `coverage.enabled` — whether coverage collection is active
- `paths.src` — source file glob
- `paths.test` — test file glob
- `ci.enabled` and `ci.provider` — CI integration status

### 2. Check for at least one data source

```
Glob for run reports:  .bestest/reports/run-*.json
Glob for scan reports: .bestest/reports/scan-*.json

If no run reports and no scan reports found:
  Print: "No report data found in .bestest/reports/."
  Print: "The doctor command needs test execution or scan data to assess health."
  Print: "Run one of these first:"
  Print: "  /bestest run --coverage    — Execute tests and capture results"
  Print: "  /bestest scan              — Full quality audit with anti-pattern detection"
  Print: "After generating data, re-run /bestest doctor."
  Exit.

If data sources found:
  Print: "Found {R} run report(s) and {S} scan report(s) in .bestest/reports/."
  Continue.
```

### 3. Check minimum dimension threshold

```
Count scorable dimensions based on available data:
  - Framework Version: always scorable if a manifest file exists (package.json, pyproject.toml, build.gradle, or go.mod)
  - Config Validity: always scorable (config loaded in check 1)
  - Coverage Trend: scorable if any run report has coverage data
  - Anti-Pattern Summary: scorable if any scan report has antiPatterns[]
  - Flaky Test Budget: scorable if any scan report has flakyTests[]
  - Dead Test Detection: scorable if any scan report has testInventory[]
  - CI Health: always evaluated (may be 'not_configured')
  - Execution Time: scorable if any run report has execution.durationMs
  - Duplicate Coverage: scorable if per-file coverage data exists

If fewer than 3 dimensions are scorable:
  Print: "Insufficient data for a meaningful health score."
  Print: "Scorable dimensions: {available}/9. Minimum required: 3."
  Print: "Generate more data:"
  Print: "  /bestest run --coverage    — Enables coverage trend, execution time"
  Print: "  /bestest scan              — Enables anti-patterns, flaky tests, dead tests"
  Print: "After generating data, re-run /bestest doctor."
  Exit.

If 3+ dimensions scorable:
  Print: "Scorable dimensions: {available}/9"
  Continue.
```

---

### 4. Version compatibility check

Compare the `.bestest/config.yaml` version to the skill version in `SKILL.md` frontmatter. This prevents subtle mismatches from config files generated by older skill versions. Also validates schemaVersion on structured artifacts per `references/schema-contract.md`.

```
1. Read the version field from SKILL.md frontmatter (the current skill version).
2. Read the version field from .bestest/config.yaml.
3. Compare versions:
   If config version is older than skill version:
     Print: "⚠ Version mismatch: .bestest/config.yaml was generated by bestest v{config_version}, but the current skill is v{skill_version}."
     Print: "  Some config fields or health check logic may not align with your configuration."
     Print: "  Consider running /bestest init to regenerate, or manually review the config."
     Add a warning to the doctor report under a new "version_mismatch" finding.
     Continue — this is a warning, not a blocker.
   If versions match or config has no version field:
     Continue silently (version field was added in a later release).
```

Validate stack-profile.json schemaVersion (if present):
  Expected version: ≤ 1.3 (current known version).
  If schemaVersion is missing:
    Treat as version "1.0" (pre-versioning legacy). Print a note and continue.
  If MAJOR version matches (1.x) and MINOR ≤ 3:
    Proceed normally.
  If MAJOR version matches but MINOR > 3:
    Print: "⚠ stack-profile.json schemaVersion {version} is newer than expected (≤ 1.3). Proceeding — unrecognized fields will be ignored."
    Continue with warning.
  If MAJOR version differs:
    Print: "Error: stack-profile.json schemaVersion {version} has an incompatible MAJOR version. Expected 1.x."
    Print: "Update bestest to the latest version, or re-run /bestest init to regenerate."
    Exit.

Validate run-results.json schemaVersion (for each run report found in Check 2):
  Expected version: "1.0" (current known version).
  If schemaVersion is missing:
    Print: "Error: run-results.json is missing schemaVersion. All run results must include schemaVersion."
    Skip this report — it may be from an incompatible version.
  If MAJOR version matches (1.x):
    Proceed normally.
  If MAJOR version differs:
    Print: "Error: run-results.json schemaVersion {version} has an incompatible MAJOR version. Expected 1.x."
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
    Skip this report.

---

## Phase 1 — Load Data Sources

Read all available artifacts into memory. This phase builds the datasets that subsequent phases score.

### Execution Steps

1. **Read config.yaml** — Already parsed during Pre-Flight. Store as `configSnapshot`.

2. **Read all run reports** — Glob for `run-*.json` files in `.bestest/reports/`. Sort by filename (timestamp-embedded names sort chronologically). For each file:

   ```
   Parse the JSON file.
   If parsing fails:
     Print: "Warning: Skipping corrupted run report: {filename}"
     Add to skippedFiles list.
     Continue to next file.

   Extract from each run-results.json:
     - timestamp: ISO 8601 string
     - summary: { totalTests, passed, failed, skipped, todo }
     - coverage: { collected, lines: { total, covered, pct }, ... }
     - execution.durationMs: total execution time
     - framework: { name, version }
   ```

3. **Read all scan reports** — Glob for `scan-*.json` files in `.bestest/reports/`. Sort by filename. For each file:

   ```
   Parse the JSON file.
   If parsing fails:
     Print: "Warning: Skipping corrupted scan report: {filename}"
     Add to skippedFiles list.
     Continue to next file.

   Extract from each scan report:
     - timestamp: ISO 8601 string
     - summary: { totalTests, totalTestFiles, passed, failed, skipped, testTypes }
     - coverage: { lines, branches, functions, statements }
     - antiPatterns[]: { file, pattern, line, severity, description }
     - flakyTests[]: { path, name, signals[], riskLevel }
     - testInventory[]: { path, type, tests, status, lastRun }
   ```

4. **Read project manifest** — Load the appropriate manifest file based on `configSnapshot.language`:

   ```
   language = configSnapshot.language (default: "javascript" if not set)

   If language is "javascript" or "typescript" (or null):
     If package.json does not exist:
       Print: "Warning: No package.json found. Framework version check will be skipped."
       Set packageJson = null
     Else:
       Parse JSON.
       Extract devDependencies (for framework version check).

   If language is "python":
     Look for pyproject.toml first, then requirements.txt
     If neither found:
       Print: "Warning: No pyproject.toml or requirements.txt found. Framework version check will be skipped."
       Set pythonManifest = null
     Else:
       Parse pyproject.toml (TOML) or requirements.txt (line-based).
       Set pythonManifest = parsed file.

   If language is "java":
     Look for build.gradle first, then pom.xml
     If neither found:
       Print: "Warning: No build.gradle or pom.xml found. Framework version check will be skipped."
       Set javaManifest = null
     Else:
       Parse build.gradle (Groovy/Kotlin DSL) or pom.xml (XML).
       Set javaManifest = parsed file.

   If language is "go":
     Look for go.mod
     If not found:
       Print: "Warning: No go.mod found. Framework version check will be skipped."
       Set goManifest = null
     Else:
       Parse go.mod (module declaration + require directives).
       Set goManifest = parsed file.
   ```

### Output

In-memory arrays: `runReports[]` (sorted oldest to newest), `scanReports[]` (sorted oldest to newest), `configSnapshot`, `packageJson` (or null), `pythonManifest` (or null), `javaManifest` (or null), `goManifest` (or null), `skippedFiles[]`.

---

## Phase 2 — Framework Version Check

**Dimension ID:** `framework-version` | **Weight:** 1.0

Extract the framework version from the project manifest and compare against the latest published version. This phase dispatches by language to use the correct manifest and version lookup strategy.

### Language-to-Manifest Mapping

| Language | Manifest File(s) | Version Lookup Command | Framework Package Mapping |
|----------|------------------|----------------------|--------------------------|
| JavaScript / TypeScript | `package.json` | `npm view <pkg> version` | vitest → "vitest", jest → "jest" |
| Python | `pyproject.toml` → `requirements.txt` | `pip index versions <pkg>` | pytest → "pytest" |
| Java | `build.gradle` → `pom.xml` | `./gradlew dependencies --configuration testRuntimeClasspath` | junit5 → "org.junit.jupiter:junit-jupiter" |
| Go | `go.mod` | `go list -m -versions <pkg>` | go_testing → "testing" (stdlib) |

### Scoring

| Condition | Score |
|-----------|-------|
| Current with latest release | 100 |
| 1 minor version behind | 80 |
| 1 major version behind | 40 |
| 2+ major versions behind | 0 |
| `go_testing` (stdlib) | 100 (always — no external dependency) |

### Execution Steps

1. **Extract installed version** — Dispatch by `configSnapshot.language`:

   ```
   language = configSnapshot.language (default: "javascript" if not set)

   If language is "javascript" or "typescript" (or null):
     If packageJson is null:
       Set dimension status = 'skipped', reason = 'no package.json'
       Skip this dimension.

     frameworkPkg = configSnapshot.framework (vitest → "vitest", jest → "jest")
     installedVersion = packageJson.devDependencies[frameworkPkg]

     If installedVersion is not found:
       Set dimension status = 'skipped', reason = 'framework not in devDependencies'
       Skip this dimension.

     Clean version: strip leading ^, ~, >=, etc.

   If language is "python":
     If pythonManifest is null:
       Set dimension status = 'skipped', reason = 'no Python manifest (pyproject.toml or requirements.txt)'
       Skip this dimension.

     frameworkPkg = "pytest" (for framework "pytest")

     Try pyproject.toml first:
       Parse [project.dependencies] and [tool.poetry.dev-dependencies] for frameworkPkg
       If found: installedVersion = extracted version

     Fallback to requirements.txt:
       Grep for line matching "^{frameworkPkg}==" or "^{frameworkPkg}>="
       Extract version after == or >= operator

     Fallback to runtime check:
       Run: pip show {frameworkPkg} --version
       Parse version from output

     If installedVersion not found by any method:
       Set dimension status = 'skipped', reason = '{frameworkPkg} version not found in manifest'
       Skip this dimension.

   If language is "java":
     If javaManifest is null:
       Set dimension status = 'skipped', reason = 'no Java manifest (build.gradle or pom.xml)'
       Skip this dimension.

     frameworkPkg = "org.junit.jupiter:junit-jupiter" (for framework "junit5")

     Try build.gradle:
       Parse dependencies { testImplementation ... } blocks for frameworkPkg
       Extract version from version declaration (e.g., "5.10.2")

     Try pom.xml:
       Parse <dependencies> → <dependency> for groupId:artifactId matching frameworkPkg
       Resolve version from <version> tag or <dependencyManagement>

     Fallback to runtime check:
       Run: ./gradlew dependencies --configuration testRuntimeClasspath 2>/dev/null
       Parse output for frameworkPkg and version

     If installedVersion not found by any method:
       Set dimension status = 'skipped', reason = 'JUnit 5 version not found in manifest'
       Skip this dimension.

   If language is "go":
     If goManifest is null:
       Set dimension status = 'skipped', reason = 'no go.mod found'
       Skip this dimension.

     If configSnapshot.framework is "go_testing":
       Go testing package is part of the standard library — no external dependency.
       Set score = 100
       Set note = "Go testing package is part of standard library (no version check needed)"
       Skip to output.
     Else:
       Parse go.mod require block for the framework package
       Extract version (e.g., "v1.8.0")
       If not found:
         Set dimension status = 'skipped', reason = 'package not in go.mod require'
         Skip this dimension.
   ```

2. **Determine latest version** — Dispatch by language for version lookup:

   ```
   If language is "javascript" or "typescript" (or null):
     Run: npm view <pkg> version

   If language is "python":
     Run: pip index versions {frameworkPkg}
     Parse the first (latest) version from output
     If pip index not available: try pip install {frameworkPkg}== 2>&1 (shows available versions)

   If language is "java":
     Parse latest from Maven Central metadata:
       curl -s "https://repo1.maven.org/maven2/org/junit/jupiter/junit-jupiter/maven-metadata.xml"
       Extract <latest> tag
     Or use gradle: ./gradlew dependencyInsight --dependency junit-jupiter

   If language is "go":
     Run: go list -m -versions {pkg}
     Parse latest from the versions list

   If the version lookup command fails (offline, CLI not available, no network):
     latestVersion = null
     Print: "Note: Could not fetch latest version. Reporting installed version only."
   ```

3. **Compare versions** — Parse semantic versions and compute the distance:

   ```
   If latestVersion is null:
     Set score = 100 (assume current — cannot verify)
     Set note = "Installed: {installedVersion}. Latest version check unavailable."
   Else:
     Parse major.minor.patch for both installed and latest.
     If majorDiff >= 2: score = 0
     Else if majorDiff == 1: score = 40
     Else if majorDiff == 0 and minorDiff >= 1: score = 80
     Else: score = 100

     Set note = "Installed: {installedVersion}, Latest: {latestVersion}"
   ```

### Output

```json
{
  "id": "framework-version",
  "label": "Framework Version",
  "status": "scored",
  "score": 80,
  "weight": 1.0,
  "note": "Installed: vitest@1.5.0, Latest: 1.6.0",
  "remediation": null
}
```

If skipped:
```json
{
  "id": "framework-version",
  "label": "Framework Version",
  "status": "skipped",
  "score": null,
  "weight": 0,
  "note": "No package.json found",
  "remediation": "Add a package.json with the test framework in devDependencies."
}
```

Go stdlib example:
```json
{
  "id": "framework-version",
  "label": "Framework Version",
  "status": "scored",
  "score": 100,
  "weight": 1.0,
  "note": "Go testing package is part of standard library (no version check needed)",
  "remediation": null
}
```

---

## Phase 3 — Config Validity Check

**Dimension ID:** `config-validity` | **Weight:** 1.5

Validate `.bestest/config.yaml` against the required fields defined in `references/config-schema.md`.

### Scoring

| Condition | Score |
|-----------|-------|
| All required fields present and valid | 100 |
| Missing optional field | −5 per field |
| Invalid field value | −15 per field |
| Config unreadable / unparseable | 0 |

### Execution Steps

1. **Check required fields** — Validate that the following fields exist and have valid values:

   | Field | Required | Valid Values |
   |-------|----------|-------------|
   | `framework` | **yes** | `"vitest"` \| `"jest"` \| `"pytest"` \| `"junit5"` \| `"go_testing"` |
   | `coverage.target` | **yes** | Number 0–100 |
   | `paths.src` | **yes** | Non-empty string |
   | `paths.test` | **yes** | Non-empty string |

2. **Check recommended optional fields** — These are not required but their absence reduces the score:

   | Field | Impact if missing |
   |-------|------------------|
   | `coverage.enabled` | −5 |
   | `coverage.provider` | −5 |
   | `ci.enabled` | −5 |
   | `e2e.enabled` | −5 |
   | `generation.quality_threshold` | −5 |

3. **Validate field values** — Check semantic correctness:

   ```
   Valid frameworks = ["vitest", "jest", "pytest", "junit5", "go_testing"]
   If framework not in validFrameworks: invalid, −15
   If coverage.target < 0 or > 100: invalid, −15
   If paths.src is empty string: invalid, −15
   If paths.test is empty string: invalid, −15

   Language-specific config block checks (recommended optional, −5 each if missing):
     If framework is "pytest": check for pytest.* block presence (e.g., pytest.config_path, pytest.testpaths)
     If framework is "junit5": check for junit5.* block presence (e.g., junit5.build_tool, junit5.test_src_dir)
     If framework is "go_testing": check for go.* block presence (e.g., go.module_path, go.go_version)

   Cross-framework block warnings (no penalty):
     If vitest.* block present when framework is not "vitest": warn only
     If jest.* block present when framework is not "jest": warn only
     If pytest.* block present when framework is not "pytest": warn only
     If junit5.* block present when framework is not "junit5": warn only
     If go.* block present when framework is not "go_testing": warn only
   ```

4. **Compute score**:

   ```
   score = 100
   For each missing optional field: score -= 5
   For each invalid field: score -= 15
   score = max(0, score)
   ```

### Output

```json
{
  "id": "config-validity",
  "label": "Config Validity",
  "status": "scored",
  "score": 90,
  "weight": 1.5,
  "note": "Missing optional fields: ci.enabled, e2e.enabled",
  "remediation": "Add ci.enabled and e2e.enabled to .bestest/config.yaml for complete configuration."
}
```

---

## Phase 4 — Coverage Trend

**Dimension ID:** `coverage-trend` | **Weight:** 1.5

Extract line coverage from recent run results and compare against the configured target.

### Scoring

| Condition | Base Score |
|-----------|-----------|
| Meeting or exceeding target | 100 |
| Within 5% of target | 80 |
| Within 15% of target | 60 |
| Within 30% of target | 40 |
| Below 30% of target | 20 |

**Trend adjustment** (when 2+ data points exist):
- Coverage improving over time: **+10**
- Coverage declining over time: **−15**

**Final score** = `min(100, max(0, baseScore + trendAdjustment))`

### Execution Steps

1. **Extract coverage data points** — From each run report with `coverage.collected === true`, extract `coverage.lines.pct`:

   ```
   dataPoints = []
   For each run report (sorted chronologically):
     If coverage.collected is true:
       dataPoints.push({ timestamp: report.timestamp, linesPct: coverage.lines.pct })

   If no data points with coverage:
     Try scan reports as fallback:
       For each scan report:
         If coverage.lines.pct > 0:
           dataPoints.push({ timestamp: report.timestamp, linesPct: coverage.lines.pct })
   ```

2. **Compute base score** — Compare latest data point against target:

   ```
   target = configSnapshot.coverage.target (default: 80)
   latest = dataPoints[dataPoints.length - 1].linesPct

   If latest >= target: baseScore = 100
   Else if latest >= target - 5: baseScore = 80
   Else if latest >= target - 15: baseScore = 60
   Else if latest >= target - 30: baseScore = 40
   Else: baseScore = 20
   ```

3. **Compute trend adjustment** — Requires at least 2 data points:

   ```
   If dataPoints.length >= 2:
     oldest = dataPoints[0].linesPct
     newest = dataPoints[dataPoints.length - 1].linesPct
     delta = newest - oldest

     If delta > 0: trendAdjustment = +10 (improving)
     Else if delta < 0: trendAdjustment = -15 (declining)
     Else: trendAdjustment = 0 (stable)
   Else:
     trendAdjustment = 0

   finalScore = min(100, max(0, baseScore + trendAdjustment))
   ```

4. **Skip condition** — If no data points at all:

   ```
   Set status = 'skipped', reason = 'no coverage data available'
   ```

### Output

```json
{
  "id": "coverage-trend",
  "label": "Coverage Trend",
  "status": "scored",
  "score": 85,
  "weight": 1.5,
  "note": "Lines: 82.7% (target: 80%) — meeting target. Trend: +4.5% over 3 runs.",
  "remediation": null
}
```

---

## Phase 5 — Anti-Pattern Summary

**Dimension ID:** `anti-patterns` | **Weight:** 1.2

Read anti-pattern findings from the most recent scan report and compute a score based on severity distribution.

### Scoring

| Condition | Score |
|-----------|-------|
| 0 anti-patterns | 100 |
| Only low severity | 90 |
| Any medium severity (no high/critical) | 75 |
| Any high severity (no critical) | 55 |
| Any critical severity | 25 |

### Execution Steps

1. **Load most recent scan report** — Use the newest `scan-*.json` that contains an `antiPatterns` array:

   ```
   For each scan report (sorted newest first):
     If report.antiPatterns exists and is an array:
       antiPatterns = report.antiPatterns
       break

   If no scan report has antiPatterns:
     Set status = 'skipped', reason = 'no scan report with anti-pattern data'
     Skip this dimension.
   ```

2. **Count by severity**:

   ```
   counts = { critical: 0, high: 0, medium: 0, low: 0 }
   For each pattern in antiPatterns:
     counts[pattern.severity]++
   ```

3. **Compute score**:

   ```
   If counts.critical > 0: score = 25
   Else if counts.high > 0: score = 55
   Else if counts.medium > 0: score = 75
   Else if counts.low > 0: score = 90
   Else: score = 100
   ```

4. **Build remediation** — For critical and high severity patterns, generate remediation entries:

   ```
   For each pattern with severity 'critical' or 'high':
     remediation = "Fix {pattern.pattern} in {pattern.file}:{pattern.line} — {pattern.description}"
   ```

### Output

```json
{
  "id": "anti-patterns",
  "label": "Anti-Pattern Summary",
  "status": "scored",
  "score": 25,
  "weight": 1.2,
  "note": "Found 8 anti-patterns: 2 critical, 2 high, 3 medium, 1 low",
  "remediation": "Fix 2 critical patterns: missing-assertions (2 instances), hardcoded-secrets (1 instance). Fix 2 high patterns: sleep-based-waits, flaky-indicators."
}
```

---

## Phase 6 — Flaky Test Budget

**Dimension ID:** `flaky-tests` | **Weight:** 1.2

Evaluate the flaky test count against a budget based on suite size.

### Scoring

| Condition | Score |
|-----------|-------|
| 0 flaky tests | 100 |
| 1 low-risk only | 95 |
| 1 medium-risk (no high) | 85 |
| 1 high-risk or 2+ medium | 70 |
| More than 3 high-risk | 30 |

### Execution Steps

1. **Load flaky test data** — From the most recent scan report:

   ```
   For each scan report (sorted newest first):
     If report.flakyTests exists and is an array:
       flakyTests = report.flakyTests
       break

   If no scan report has flakyTests:
     Set status = 'skipped', reason = 'no scan report with flaky test data'
     Skip this dimension.
   ```

2. **Count by risk level**:

   ```
   counts = { high: 0, medium: 0, low: 0 }
   For each test in flakyTests:
     counts[test.riskLevel]++
   ```

3. **Compute score**:

   ```
   If counts.high > 3: score = 30
   Else if counts.high >= 1 or counts.medium >= 2: score = 70
   Else if counts.medium == 1 and counts.high == 0: score = 85
   Else if counts.low >= 1 and counts.high == 0 and counts.medium == 0: score = 95
   Else if flakyTests.length == 0: score = 100
   Else: score = 95
   ```

4. **Build remediation** — For high-risk flaky tests:

   ```
   For each test with riskLevel 'high':
     remediation = "Stabilize '{test.name}' in {test.path} — signals: {test.signals.join(', ')}"
   ```

### Output

```json
{
  "id": "flaky-tests",
  "label": "Flaky Test Budget",
  "status": "scored",
  "score": 70,
  "weight": 1.2,
  "note": "2 flaky tests: 1 high-risk, 1 medium-risk",
  "remediation": "Stabilize 'Payment Service > processPayment > handles timeout' — signals: network-calls, long-execution"
}
```

---

## Phase 7 — Dead Test Detection

**Dimension ID:** `dead-tests` | **Weight:** 0.8

Identify tests that are skipped, todo, or otherwise not executing. These represent dead weight in the suite.

### Scoring

| Condition | Score |
|-----------|-------|
| 0% dead tests | 100 |
| <5% dead | 85 |
| <10% dead | 70 |
| <20% dead | 50 |
| ≥20% dead | 25 |

### Execution Steps

1. **Count dead tests from scan report** — From the most recent scan's `testInventory[]`:

   ```
   For each scan report (sorted newest first):
     If report.testInventory exists and is an array:
       inventory = report.testInventory
       summary = report.summary
       break

   If no scan report with testInventory:
     Set status = 'skipped', reason = 'no scan report with test inventory'
     Skip this dimension.
   ```

2. **Count skipped/todo tests**:

   ```
   skippedCount = summary.skipped (from scan report)
   totalCount = summary.totalTests

   Also scan test files for explicit skip/todo patterns:
   For each file in testInventory:
     Grep for test.skip, it.skip, test.todo, it.todo, describe.skip
     Count matches (approximate — each match ≈ 1 skipped test)

   deadCount = max(skippedCount, grepMatchCount)
   deadPct = (deadCount / totalCount) * 100 (if totalCount > 0, else 0)
   ```

3. **Compute score**:

   ```
   If deadPct == 0: score = 100
   Else if deadPct < 5: score = 85
   Else if deadPct < 10: score = 70
   Else if deadPct < 20: score = 50
   Else: score = 25
   ```

4. **Build remediation** — If dead tests detected:

   ```
   If deadCount > 0:
     remediation = "{deadCount} tests are skipped/todo ({deadPct}%). Review and either implement or remove them."
   ```

### Output

```json
{
  "id": "dead-tests",
  "label": "Dead Tests",
  "status": "scored",
  "score": 85,
  "weight": 0.8,
  "note": "3 skipped/todo tests out of 142 total (2.1%)",
  "remediation": null
}
```

---

## Phase 8 — CI Health Check

**Dimension ID:** `ci-health` | **Weight:** 0.8 (when available)

Check for CI pipeline configuration and recent pipeline health. This dimension is **special**: if no CI is configured, it reports `not_configured` and is **excluded from the composite score** entirely — it does not penalize projects without CI. However, when CI files exist (e.g., generated by spoke-ci.md), the dimension is **scored** even if the CLI/API for live health checks is unavailable — it reports `scored` with score=70 (configured_unknown).

### Scoring (when CI is configured)

| Condition | Score |
|-----------|-------|
| CI configured and all recent runs green | 100 |
| CI configured and most runs green (>80%) | 85 |
| CI configured and runs are mixed (50–80%) | 60 |
| CI configured and runs are failing (<50%) | 30 |
| CI configured but status unknown (no CLI or API access) | 70 |

### Execution Steps

1. **Detect CI configuration** — Check for common CI config files and cross-reference with `config.yaml`:

   ```
   ciFiles = []
   Check for: .github/workflows/*.yml, .github/workflows/*.yaml
   Check for: .gitlab-ci.yml
   Check for: Jenkinsfile
   Check for: .circleci/config.yml

   ciEnabled = configSnapshot.ci.enabled
   ciProvider = configSnapshot.ci.provider

   If ciFiles found:
     If ciEnabled is true:
       Set hasCI = true
       Set provider = ciProvider (or detect from file presence)
       If provider is null:
         Detect from files:
           .github/workflows/ → "github-actions"
           .gitlab-ci.yml → "gitlab-ci"
           Jenkinsfile → "jenkins"
           .circleci/config.yml → "circleci"

     Else if ciEnabled is not true (false or absent):
       CI files exist but ci.enabled is not true — spoke-ci.md hasn't run or config was manually edited
       Set hasCI = true
       Set note = "CI files present but ci.enabled is false in config"
       Set provider = detect from files (as above)

   Else (no CI files found):
     If ciEnabled is true:
       CI declared in config but files missing — may need re-generation
       Set hasCI = false
       Set status = 'not_configured', weight = 0
       Note = "ci.enabled is true but no CI files found. Run /bestest ci to generate."

     Else:
       Set status = 'not_configured', weight = 0
       Note = "No CI pipeline detected. This dimension does not affect your score."
   ```

2. **Check CI health** — If CI is configured (`hasCI = true`), perform provider-specific health checks:

   ```
   If provider is "github-actions" (or detected from .github/workflows/):
     If gh CLI is available AND project is on GitHub:
       Run: gh run list --limit 5 --json status,conclusion
       Count successes vs failures from recent runs
       Compute score from success rate:
         5/5 green → 100
         4/5 green → 85
         3/5 green → 60
         <3/5 green → 30
     Else:
       Set score = 70, note = "GitHub Actions configured (health check requires gh CLI and repository access)"

   If provider is "gitlab-ci" (or detected from .gitlab-ci.yml):
     If glab CLI is available:
       Run: glab ci list --per-page 5 (or parse pipeline status)
       Count successes vs failures from recent pipelines
       Compute score from success rate (same thresholds as GitHub)
     Else:
       Set score = 70, note = "GitLab CI configured (health check requires glab CLI)"

   If provider is "jenkins" (or detected from Jenkinsfile):
     If jenkins-cli is available:
       Run: jenkins-cli build-status <job> (or equivalent)
       Parse last build result
     Else if curl to Jenkins API is available (JENKINS_URL + API token in env):
       Curl: $JENKINS_URL/job/<job>/api/json?tree=builds[result]
       Parse build results
     Else:
       Set score = 70, note = "Jenkins configured (health check requires Jenkins API access)"

   If provider is "circleci" (or detected from .circleci/config.yml):
     If circleci CLI is available:
       Run: circleci build-agent check or recent pipeline API
       Parse pipeline status
     Else:
       Set score = 70, note = "CircleCI configured (health check requires CircleCI CLI or API token)"

   If provider is unknown or unsupported:
     Set score = 70, note = "CI configured with unknown provider (health check requires provider-specific CLI)"

   Key: When CI files exist (from spoke-ci.md) but CLI/API is unavailable, score = 70 (configured_unknown) instead of not_configured.
   ```

3. **Handle not_configured gracefully**:

   ```
   When status is 'not_configured':
     This dimension is excluded from composite score calculation.
     weight = 0 in the formula.
     Print: "CI Health: not configured — this does not affect your score."
     Print: "To set up CI: /bestest ci"
   ```

### Output

When configured:
```json
{
  "id": "ci-health",
  "label": "CI Health",
  "status": "scored",
  "score": 100,
  "weight": 0.8,
  "note": "GitHub Actions: 5/5 recent runs passed",
  "remediation": null
}
```

When configured but CLI unavailable:
```json
{
  "id": "ci-health",
  "label": "CI Health",
  "status": "scored",
  "score": 70,
  "weight": 0.8,
  "note": "GitLab CI configured (health check requires glab CLI)",
  "remediation": "Install glab CLI for live CI health monitoring"
}
```

When not configured:
```json
{
  "id": "ci-health",
  "label": "CI Health",
  "status": "not_configured",
  "score": null,
  "weight": 0,
  "note": "No CI pipeline detected. Set up CI with: /bestest ci",
  "remediation": null
}
```

---

## Phase 9 — Execution Time

**Dimension ID:** `execution-time` | **Weight:** 1.0

Evaluate test suite execution speed from run reports.

### Scoring

| Condition | Score |
|-----------|-------|
| < 30 seconds | 100 |
| < 60 seconds | 90 |
| < 120 seconds | 75 |
| < 300 seconds | 60 |
| ≥ 300 seconds | 30 |

**Trend adjustment** (when 2+ data points):
- Suite getting faster: **+10**
- Suite getting slower: **−10**

**Final score** = `min(100, max(0, baseScore + trendAdjustment))`

### Execution Steps

1. **Extract execution times** — From run reports:

   ```
   dataPoints = []
   For each run report (sorted chronologically):
     If execution.durationMs exists and > 0:
       dataPoints.push({ timestamp: report.timestamp, durationMs: execution.durationMs })

   If no data points:
     Set status = 'skipped', reason = 'no run reports with execution timing'
     Skip this dimension.
   ```

2. **Compute base score**:

   ```
   latestDurationMs = dataPoints[dataPoints.length - 1].durationMs
   latestDurationSec = latestDurationMs / 1000

   If latestDurationSec < 30: baseScore = 100
   Else if latestDurationSec < 60: baseScore = 90
   Else if latestDurationSec < 120: baseScore = 75
   Else if latestDurationSec < 300: baseScore = 60
   Else: baseScore = 30
   ```

3. **Compute trend** — Requires at least 2 data points:

   ```
   If dataPoints.length >= 2:
     oldest = dataPoints[0].durationMs
     newest = dataPoints[dataPoints.length - 1].durationMs

     If newest < oldest * 0.9: trendAdjustment = +10 (speeding up)
     Else if newest > oldest * 1.1: trendAdjustment = -10 (slowing down)
     Else: trendAdjustment = 0 (stable)
   Else:
     trendAdjustment = 0

   finalScore = min(100, max(0, baseScore + trendAdjustment))
   ```

### Output

```json
{
  "id": "execution-time",
  "label": "Execution Time",
  "status": "scored",
  "score": 90,
  "weight": 1.0,
  "note": "Latest run: 5.1s. Trend: stable over 3 runs.",
  "remediation": null
}
```

---

## Phase 10 — Duplicate Coverage

**Dimension ID:** `duplicate-coverage` | **Weight:** 0.5

Informational dimension detecting tests that cover the same code paths multiple times. This dimension has low weight because per-file coverage overlap data is rarely available without specialized tooling.

### Scoring

| Condition | Score |
|-----------|-------|
| No significant overlap detected | 100 |
| Minor overlap (< 20% of files have >3 tests covering same lines) | 80 |
| Moderate overlap (20–40% of files) | 60 |
| Heavy overlap (>40% of files) | 40 |
| No per-file coverage data available | skipped |

### Execution Steps

1. **Check for per-file coverage data** — From the most recent scan or run report:

   ```
   If scan report has per-file coverage in coverage map:
     Use per-file coverage data
   Else if run report has Istanbul coverage-summary.json:
     Parse per-file coverage
   Else:
     Set status = 'skipped', reason = 'no per-file coverage data'
     Skip this dimension.
   ```

2. **Detect overlap** — For files with per-file coverage:

   ```
   For each source file:
     Find all test files that import it (via grep for import/require of the source file)
     If a source file is imported by 3+ test files:
       Flag as potential duplicate coverage

   overlapPct = (files with 3+ test consumers / total source files) * 100
   ```

3. **Compute score**:

   ```
   If overlapPct == 0: score = 100
   Else if overlapPct < 20: score = 80
   Else if overlapPct < 40: score = 60
   Else: score = 40
   ```

### Output

```json
{
  "id": "duplicate-coverage",
  "label": "Duplicate Coverage",
  "status": "skipped",
  "score": null,
  "weight": 0,
  "note": "Per-file coverage overlap analysis requires Istanbul per-file data. Not available in current reports.",
  "remediation": null
}
```

---

## Composite Scoring

Compute the weighted average of all **scored** dimensions. Skipped dimensions and dimensions with `status: 'not_configured'` are excluded from both the numerator and the denominator.

### Formula

```
compositeScore = sum(score * weight for each scored dimension) / sum(weight for each scored dimension)
```

Round to the nearest integer (0–100).

### Score Bands

| Range | Status | Indicator |
|-------|--------|-----------|
| 90–100 | Excellent | 🟢 |
| 75–89 | Good | 🟢 |
| 60–74 | Fair | 🟡 |
| 40–59 | Needs Attention | 🟠 |
| 0–39 | Critical | 🔴 |

### Minimum Dimensions

A composite score requires at least **3 scorable dimensions**. If fewer than 3 are available (checked in Pre-Flight), the doctor cannot produce a meaningful score and exits with a diagnostic warning.

### Example Computation

```
Framework Version:  100 × 1.0 = 100.0
Config Validity:     90 × 1.5 = 135.0
Coverage Trend:      85 × 1.5 = 127.5
Anti-Patterns:       55 × 1.2 =  66.0
Flaky Tests:         70 × 1.2 =  84.0
Dead Tests:          85 × 0.8 =  68.0
CI Health:           not_configured (excluded)
Execution Time:      90 × 1.0 =  90.0
Duplicate Coverage:  skipped (excluded)

Numerator:   100.0 + 135.0 + 127.5 + 66.0 + 84.0 + 68.0 + 90.0 = 670.5
Denominator: 1.0 + 1.5 + 1.5 + 1.2 + 1.2 + 0.8 + 1.0 = 8.2
Composite:   670.5 / 8.2 = 81.8 → rounded to 82

Status: Good 🟢
```

---

## Phase 11 — Generate Report

Assemble all dimension scores and the composite score into a structured health report, write it to disk, update config state, and print a console summary.

### Execution Steps

1. **Generate the report timestamp**:

   ```
   timestamp = currentDateTime formatted as ISO 8601 (e.g., 2024-07-15T14:30:45.123Z)
   filename_ts = currentDateTime formatted as YYYYMMDDTHHmmssZ
   ```

2. **Assemble health report JSON** — Combine all dimension results into the report structure:

   ```json
   {
     "timestamp": "<ISO 8601>",
     "healthScore": 82,
     "status": "Good",
     "indicator": "🟢",
     "dimensions": {
       "framework-version": { ... },
       "config-validity": { ... },
       "coverage-trend": { ... },
       "anti-patterns": { ... },
       "flaky-tests": { ... },
       "dead-tests": { ... },
       "ci-health": { ... },
       "execution-time": { ... },
       "duplicate-coverage": { ... }
     },
     "remediation": [
       {
         "priority": 1,
         "dimension": "anti-patterns",
         "action": "Fix 2 critical patterns: missing-assertions, hardcoded-secrets",
         "command": "/bestest fix"
       },
       {
         "priority": 2,
         "dimension": "flaky-tests",
         "action": "Stabilize 1 high-risk flaky test in payment service",
         "command": "/bestest fix --flaky"
       }
     ],
     "configSnapshot": { ... },
     "skippedFiles": []
   }
   ```

3. **Build prioritized remediation list** — Collect remediation entries from all dimensions, sorted by impact:

   ```
   remediation = []
   For each dimension (sorted by weight descending, then score ascending):
     If dimension.remediation is not null:
       remediation.push({
         priority: remediation.length + 1,
         dimension: dimension.id,
         action: dimension.remediation,
         command: suggestCommand(dimension.id)
       })

   Suggested commands (language-aware):
     anti-patterns → "/bestest fix"
     flaky-tests → "/bestest fix --flaky"
     coverage-trend → "/bestest coverage"
     dead-tests → "/bestest generate --untested"
     framework-version (language-aware):
       If language is "python": "pip install --upgrade {framework}"
       If language is "java": "Update build.gradle testImplementation dependency for {framework}"
       If language is "go": "go get -u {package}"
       Else (javascript/typescript): "npm install --save-dev {framework}@latest"
     config-validity → "/bestest init (to regenerate config)"
     execution-time → "/bestest run --filter unit"
     ci-health → "/bestest ci"
     duplicate-coverage → "/bestest scan (for per-file coverage analysis)"
   ```

4. **Write JSON report** — Write to `.bestest/reports/doctor-<filename_ts>.json`:

   ```
   Ensure .bestest/reports/ directory exists (mkdir -p .bestest/reports).
   Write the full JSON to .bestest/reports/doctor-{filename_ts}.json.
   Never overwrite or delete existing reports. All prior reports are preserved.
   If a report with the same timestamp exists (extremely unlikely), append a -2 suffix.
   ```

5. **Update config state** — Write the report timestamp to `.bestest/config.yaml`:

   ```yaml
   state:
     last_doctor: "<ISO 8601 timestamp>"
   ```

   Read the existing config, update only the `state.last_doctor` field, and write back. Preserve all other config fields exactly. Do not modify `state.last_scan`, `state.last_run`, `state.last_report`, or any other field.

   If the `state.last_doctor` field does not yet exist in config.yaml, add it alongside existing state fields.

6. **Print console summary** — Display a human-readable summary with dimension table:

   ```
   ## bestest doctor

   Language: {configSnapshot.language or "auto-detected"}
   Framework: {configSnapshot.framework}
   Health Score: 82/100 — Good 🟢

   ### Dimensions

   | # | Dimension | Score | Status | Note |
   |---|-----------|-------|--------|------|
   | 1 | Framework Version | 100 ✅ | scored | vitest@1.6.0 (current) |
   | 2 | Config Validity | 90 ✅ | scored | Missing: ci.enabled, e2e.enabled |
   | 3 | Coverage Trend | 85 ✅ | scored | 82.7% lines (target: 80%) ↑ improving |
   | 4 | Anti-Patterns | 55 ⚠️ | scored | 2 critical, 2 high, 3 medium, 1 low |
   | 5 | Flaky Tests | 70 ⚠️ | scored | 1 high-risk, 1 medium-risk |
   | 6 | Dead Tests | 85 ✅ | scored | 3 skipped (2.1%) |
   | 7 | CI Health | — | not_configured | No CI pipeline detected |
   | 8 | Execution Time | 90 ✅ | scored | 5.1s — stable |
   | 9 | Duplicate Coverage | — | skipped | No per-file coverage data |

   ### Prioritized Remediation

   1. **Anti-patterns**: Fix 2 critical patterns → `/bestest fix`
   2. **Flaky tests**: Stabilize 1 high-risk test → `/bestest fix --flaky`
   3. **Coverage**: Maintain or improve current 82.7% → `/bestest coverage`

   ### Report
   - Written to: .bestest/reports/doctor-{filename_ts}.json
   - config.yaml state.last_doctor updated

   ### Next Steps
   - Address critical remediation items above
   - Run /bestest doctor again after changes to track improvement
   - Set up CI with: /bestest ci
   ```

### Output

| Artifact | Location | Purpose |
|----------|----------|---------|
| Health report JSON | `.bestest/reports/doctor-<timestamp>.json` | Machine-readable health report with all dimension scores |
| Updated config state | `.bestest/config.yaml` | `state.last_doctor` set to report timestamp |
| Console summary | Terminal | Human-readable health score with dimension table and remediation |

---

## Metrics Update

After Phase 11 completes and all artifacts are written, update `.bestest/state/metrics.json` per the shared protocol in `references/metrics-schema.md`. The doctor spoke is focused on health score aggregation — it writes the most authoritative `healthScore` snapshot and an activity log entry.

### Protocol

1. **Read `.bestest/state/metrics.json`** — If the file does not exist, treat as first-time creation with defaults from `metrics-schema.md`.
2. **Parse** — If parsing fails (corruption), log a warning and reinitialize with defaults plus current doctor data. **Never abort the spoke** — metrics are observability, not a gate.
3. **Validate `schemaVersion`** — Warn if MAJOR version differs; proceed if MINOR differs.
4. **Merge spoke-specific data** (see field mapping below).
5. **Write back** — Atomic write (write to temp file, then rename).
6. **Update `config.yaml`** — Set `state.last_metrics` to current ISO 8601 timestamp.

### Fields Updated by spoke-doctor

| Metrics Section | Source Data | Merge Logic |
|----------------|------------|-------------|
| `healthScore.overall` | Composite score from Phase 11 | Replace with `healthScore / 100` (doctor scores 0–100, metrics uses 0.0–1.0). Round to 2 decimal places. |
| `healthScore.breakdown.coverage` | Coverage Trend dimension score | Replace with `dimensionScore / 100` if dimension is `scored`; set to `null` if `skipped` or `not_configured`. |
| `healthScore.breakdown.flakiness` | Flaky Test Budget dimension score | Replace with `dimensionScore / 100` if `scored`; set to `null` if `skipped`. |
| `healthScore.breakdown.passRate` | Not directly measured by doctor | Leave unchanged (populated by spoke-run). |
| `healthScore.breakdown.freshness` | Current time vs `lastUpdated` | Set to 1.0 (just updated). |
| `healthScore.breakdown.mutation` | Not measured by doctor | Leave unchanged (remains `null` unless mutation testing is configured). |
| `activity[]` | Doctor summary | Append `{ timestamp, spoke: "spoke-doctor", action: "doctor", summary: "Health score: {score}/100 ({status}) — {count} dimensions scored" }`. Evict oldest entries exceeding `activityMaxLength` (200). |
| `lastUpdated` | Current time | Set to current ISO 8601 timestamp. |

### Health Score Derivation

The doctor's composite score (0–100) maps to the metrics `healthScore.overall` (0.0–1.0) via simple division:

```
metrics.healthScore.overall = doctorReport.healthScore / 100
```

Per-dimension scores that were `scored` map to breakdown fields via the same division. Dimensions that were `skipped` or `not_configured` map to `null` and are excluded from the overall average per the formula in `metrics-schema.md`.

### Bounded Array Eviction

All arrays use FIFO eviction: append new entry to end, then remove from beginning if length exceeds `*maxLength`. See `metrics-schema.md` → Bounded Array Eviction for the canonical algorithm.

> **Dashboard refresh:** The health dashboard at `.bestest/dashboard.html` reads `state/metrics.json` on each page load — the metrics update above is all that's needed to refresh the dashboard. No separate dashboard rebuild step is required.

---

## Error Handling

### 1. No `.bestest/` directory

**Trigger**: Pre-Flight Check 1 finds `.bestest/` does not exist.

**Response**:
```
Print: "No .bestest/ directory found. Run /bestest init first to set up testing infrastructure."
```
Exit. No report is written.

### 2. Invalid config.yaml

**Trigger**: `.bestest/config.yaml` is missing, empty, or contains invalid YAML.

**Response**:
```
Print: ".bestest/config.yaml is missing or invalid."
Print: "Run /bestest init to regenerate it, or fix the syntax error."
```
Exit. No report is written.

### 3. No data sources at all

**Trigger**: `.bestest/reports/` contains no `run-*.json` or `scan-*.json` files.

**Response**:
```
Print: "No report data found in .bestest/reports/."
Print: "The doctor command needs at least one run or scan report to assess health."
Print: "Generate data first:"
Print: "  /bestest run --coverage    — Execute tests and capture results"
Print: "  /bestest scan              — Full quality audit with anti-pattern detection"
```
Exit. No report is written.

### 4. Fewer than 3 available dimensions

**Trigger**: After evaluating data availability, fewer than 3 dimensions can produce a score.

**Response**:
```
Print: "Insufficient data for a meaningful health score."
Print: "Only {N}/9 dimensions can be scored. Minimum required: 3."
Print: "Generate more data to enable additional dimensions:"
Print: "  /bestest run --coverage    — Enables: coverage trend, execution time"
Print: "  /bestest scan              — Enables: anti-patterns, flaky tests, dead tests"
```
Exit. No report is written. The user receives clear guidance on which commands will unlock more dimensions.

### 5. Corrupted JSON artifacts

**Trigger**: Phase 1 encounters a `run-*.json` or `scan-*.json` file that cannot be parsed as valid JSON.

**Response**:
```
Print: "Warning: Skipping corrupted report file: {filename}"
Print: "The file contains invalid JSON and cannot be processed."
Print: "Other valid reports will be used normally."
```
Skip the file. Continue processing valid files. Add the filename to `skippedFiles[]` in the report. If the corrupted file was the only data source for a dimension, that dimension is marked as skipped.

### 6. package.json missing

**Trigger**: Phase 2 (Framework Version) cannot find `package.json` at the project root.

**Response**:
```
Print: "No package.json found. Framework version check will be skipped."
```
Set the Framework Version dimension to `skipped`. The composite score is computed without this dimension. Other dimensions that don't depend on `package.json` are unaffected.

### 7. Framework not in devDependencies

**Trigger**: Phase 2 finds `package.json` but the configured framework is not listed in `devDependencies`.

**Response**:
```
Print: "Config specifies {framework} but it is not in package.json devDependencies."
Print: "Framework version check will be skipped."
```
Set the Framework Version dimension to `skipped`. This may indicate a misconfigured project — the Config Validity dimension will also flag this as a warning.

### 8. Config state.last_doctor field missing

**Trigger**: Phase 11 Step 5 attempts to update `state.last_doctor` in `config.yaml` but the field does not exist.

**Response**:
```
Read existing config.yaml.
Locate the state: section.
If state: section exists:
  Add last_doctor field after existing fields.
If state: section does not exist:
  Create state: section with last_doctor and preserve any existing state fields.
Write updated config.yaml.
```
Non-fatal. The report is still written successfully.

### 9. Python manifest not found

**Trigger**: Phase 2 (Framework Version) is dispatched for Python but neither `pyproject.toml` nor `requirements.txt` exists.

**Response**:
```
Print: "No pyproject.toml or requirements.txt found. Framework version check will be skipped."
```
Set the Framework Version dimension to `skipped`. The composite score is computed without this dimension. Other dimensions that don't depend on Python manifests are unaffected.

### 10. Java manifest not found

**Trigger**: Phase 2 (Framework Version) is dispatched for Java but neither `build.gradle` nor `pom.xml` exists.

**Response**:
```
Print: "No build.gradle or pom.xml found. Framework version check will be skipped."
```
Set the Framework Version dimension to `skipped`. This may indicate a misconfigured project — the Config Validity dimension will also flag this as a warning. Other dimensions are unaffected.

### 11. Go manifest not found

**Trigger**: Phase 2 (Framework Version) is dispatched for Go but `go.mod` does not exist.

**Response**:
```
Print: "No go.mod found. Framework version check will be skipped."
```
Set the Framework Version dimension to `skipped`. The composite score is computed without this dimension. Other dimensions are unaffected.

---

## Output

### Health Report JSON Schema

The health report written to `.bestest/reports/doctor-<timestamp>.json` follows this schema:

```json
{
  "timestamp": "string (ISO 8601)",
  "healthScore": "integer (0–100)",
  "status": "string: Excellent | Good | Fair | Needs Attention | Critical",
  "indicator": "string: 🟢 | 🟡 | 🟠 | 🔴",
  "dimensions": {
    "<dimension-id>": {
      "id": "string (kebab-case)",
      "label": "string (human-readable)",
      "status": "string: scored | skipped | not_configured",
      "score": "integer (0–100) or null",
      "weight": "number (0–1.5)",
      "note": "string (contextual explanation)",
      "remediation": "string or null"
    }
  },
  "remediation": [
    {
      "priority": "integer (1-based)",
      "dimension": "string (dimension id)",
      "action": "string (human-readable action)",
      "command": "string (suggested bestest command)"
    }
  ],
  "configSnapshot": "object (from config.yaml)",
  "skippedFiles": ["string (filenames of corrupted/invalid reports)"]
}
```

### Console Output Format

The console summary uses markdown-formatted tables with emoji indicators for quick visual scanning:

1. **Header line**: Health score, status label, and emoji indicator
2. **Dimension table**: All 9 dimensions with score, status, and contextual note
3. **Remediation list**: Prioritized actions with suggested commands
4. **Report metadata**: File path and config state update confirmation
5. **Next steps**: Contextual suggestions based on current health

### Report Retention

- All doctor reports are preserved — the command never deletes previous reports
- Downstream tooling can compare consecutive reports to track health score trajectory
- The report is self-contained: no cross-references needed to understand the health assessment

---

## Downstream Reference

### Terminal Spoke

The doctor command is a **terminal spoke**: no other bestest command consumes its output. The health report JSON is designed for human consumption and CI dashboards — developers reading it in a text editor, CI artifact viewer, or monitoring tool. It is not consumed by generate, fix, run, scan, or report spokes.

### Input Data Contracts

The doctor spoke reads data from these sources:

#### Run Reports (`run-*.json`)

Source: `references/spoke-run.md` — run-results.json shape

| Field Used | Dimension | Purpose |
|-----------|-----------|---------|
| `coverage.lines.pct` | Coverage Trend | Line coverage percentage for trend analysis |
| `coverage.collected` | Coverage Trend | Whether coverage data is available |
| `execution.durationMs` | Execution Time | Total test execution duration |
| `framework.version` | Framework Version | Cross-reference with package.json |
| `timestamp` | Coverage Trend, Execution Time | Chronological ordering for trend computation |

#### Scan Reports (`scan-*.json`)

Source: `references/spoke-scan.md` — scan report schema

| Field Used | Dimension | Purpose |
|-----------|-----------|---------|
| `antiPatterns[]` | Anti-Pattern Summary | Pattern detection results with severity |
| `antiPatterns[].severity` | Anti-Pattern Summary | Severity distribution scoring |
| `flakyTests[]` | Flaky Test Budget | Flaky test count and risk levels |
| `flakyTests[].riskLevel` | Flaky Test Budget | Risk-level distribution scoring |
| `testInventory[]` | Dead Tests | Test status for skip/todo detection |
| `summary.skipped` | Dead Tests | Skipped test count |
| `summary.totalTests` | Dead Tests | Total for percentage calculation |
| `coverage.lines.pct` | Coverage Trend | Fallback coverage data point |

#### Configuration (`config.yaml`)

Source: `references/config-schema.md`

| Field Used | Dimension | Purpose |
|-----------|-----------|---------|
| `framework` | Framework Version, Config Validity | Framework identification and validation |
| `language` | Framework Version, Config Validity, Report | Language dispatch for version check, config block validation, and console summary |
| `coverage.target` | Coverage Trend | Target for coverage comparison |
| `coverage.enabled` | Config Validity | Configuration completeness check |
| `paths.src` | Config Validity | Required field validation |
| `paths.test` | Config Validity | Required field validation |
| `ci.enabled` | CI Health | CI pipeline detection |
| `ci.provider` | CI Health | CI platform identification |

#### Project Files

| File | Dimension | Purpose |
|------|-----------|---------|
| `package.json` | Framework Version | Installed version from devDependencies (JS/TS) |
| `pyproject.toml` | Framework Version | Python dependency versions (Python) |
| `requirements.txt` | Framework Version | Python dependency versions (fallback) |
| `build.gradle` | Framework Version | Java dependency versions (Java) |
| `pom.xml` | Framework Version | Java dependency versions (Java fallback) |
| `go.mod` | Framework Version | Go module versions (Go) |
| `.github/workflows/*.yml` | CI Health | GitHub Actions pipeline detection |
| `.gitlab-ci.yml` | CI Health | GitLab CI pipeline detection |
| `Jenkinsfile` | CI Health | Jenkins pipeline detection |
| `.circleci/config.yml` | CI Health | CircleCI pipeline detection |

### Config State Contract

The doctor spoke writes one field to `config.yaml`:

| Field | Type | Written By | Description |
|-------|------|-----------|-------------|
| `state.last_doctor` | string or null | Doctor spoke | ISO 8601 timestamp of last health check |

This field is added by the doctor spoke and is not present in the initial config created by `init`. Phase 11 Step 5 handles the field's absence gracefully (see Error Handling scenario 8).
