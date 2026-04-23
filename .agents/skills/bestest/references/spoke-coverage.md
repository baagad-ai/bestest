# /bestest coverage

## Purpose

Lighter-weight alternative to `scan` that focuses purely on coverage gap analysis. Compares existing coverage data (from `run-results.json` or a scan report) against the targets defined in `config.yaml`, identifies untested and under-tested modules, and presents actionable gaps grouped by priority, module, and type. When gaps are found, an auto-chain HITL gate offers to invoke the generate spoke to address selected gaps immediately.

The coverage command is **read-only**: it never re-runs the test suite or modifies source code. It reads existing coverage artifacts, performs analysis, and writes a structured report. Use it after a `run --coverage` or `scan` to understand exactly where coverage falls short without waiting for a full scan.

Three invocation modes:

| Invocation | Behavior |
|-----------|----------|
| `/bestest coverage` | Full coverage gap analysis against configured targets |
| `/bestest coverage --module <name>` | Scope analysis to a single module/directory |
| `/bestest coverage --format json` | Machine-readable output (suppresses console summary, writes JSON only) |

Relationship to other commands:
- **`scan`** produces the same gap analysis as part of a broader audit (anti-patterns, flakiness, test inventory). `coverage` extracts and deepens just the gap/target portion.
- **`run --coverage`** produces `run-results.json` with coverage metrics. `coverage` consumes that data for comparison against targets.
- **`generate`** consumes the `gaps[]` array that `coverage` produces, using it to select generation targets and prioritize work.

## Prerequisites

- `.bestest/` directory must exist with valid `config.yaml` (run `/bestest init` first)
- **At least one data source** must be available:
  - `run-results.json` from a prior `/bestest run` with coverage enabled, OR
  - A scan report from `.bestest/reports/scan-*.json`
- If neither data source exists, suggest running `scan` or `run --coverage` first

## Pre-Flight Checks

Run these checks before starting analysis. They guard against invalid states and give the user early, actionable feedback.

### 1. Check for `.bestest/` with valid config

```
If .bestest/ does not exist:
  Print: "No .bestest/ directory found. Run /bestest init first to set up testing infrastructure."
  Exit.

If .bestest/config.yaml does not exist:
  Print: ".bestest/config.yaml is missing. The config file is required for coverage analysis."
  Print: "Run /bestest init to regenerate it, or restore it from version control."
  Exit.

If .bestest/config.yaml exists but is invalid YAML:
  Print: ".bestest/config.yaml contains invalid YAML and cannot be parsed."
  Print: "Fix the syntax error and re-run /bestest coverage."
  Exit.
```

Parse required fields:
- `coverage.target` — numeric threshold (0–100) to compare against
- `paths.src` — glob pattern for source discovery
- `paths.ignore` — exclusions

If `coverage` section is missing entirely, treat it as default: `coverage.enabled: true`, `coverage.target: 80`.

### 2. Detect data source

```
Priority order for data source selection:
  1. Most recent run-results.json (from .bestest/reports/run-*.json)
     - Must have coverage.collected === true
     - Provides both aggregate metrics and per-file coverage
  2. Most recent scan report (from .bestest/reports/scan-*.json)
     - Contains coverage block and gaps[] from prior scan
     - Provides aggregate metrics, per-file coverage from Phase 3, and pre-computed gaps
  3. Language-specific raw coverage artifacts (when framework is known from config.yaml):
     - Python (pytest): .bestest/reports/coverage.json (coverage.py JSON from pytest-cov)
     - Java (junit5): build/reports/jacoco/test/jacocoTestReport.xml (Gradle) or
                       target/site/jacoco/jacoco.xml (Maven)
     - Go (go_testing): .bestest/reports/go-coverage.out (Go coverage profile)
     These are parsed directly into the unified metrics shape (see Phase 1 Step 3).

If no run-results.json and no scan report found:
  If a raw coverage artifact is available for the configured framework:
    Print: "No run-results or scan report found. Using raw {framework} coverage artifact."
    Print: "For richer analysis, run /bestest run --coverage first."
    Proceed with raw artifact parsing.
  Else:
    Print: "No coverage data found. Run one of these first:"
    Print: "  /bestest run --coverage    — Execute tests with coverage collection"
    Print: "  /bestest scan              — Full audit including coverage analysis"
    Exit.

Print: "Using data source: {filename} ({timestamp})"
```

### 3. Check coverage.enabled

```
If config.yaml has coverage.enabled === false:
  Print: "Warning: coverage.enabled is set to false in config.yaml."
  Print: "Coverage targets cannot be enforced when collection is disabled."
  Print: "Analysis will proceed using available data, but results may be stale."
  Print: "Run /bestest config set coverage.enabled true to enable coverage collection."
  Continue with available data.
```

### 4. Verify source files exist

```
Glob for source files using paths.src pattern from config.yaml, excluding paths.ignore.

If zero source files found:
  Print: "No source files found matching pattern: {paths.src}"
  Print: "Check that paths.src in .bestest/config.yaml points to your source code."
  Exit.

If source files found:
  Print: "Found {N} source file(s) matching {paths.src}."
  Continue.
```

### 5. Validate artifact schemaVersions

Reference: `references/schema-contract.md` for version policy and validation algorithm.

```
Validate run-results.json schemaVersion (if a run report was found in Check 2):
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

Validate scan-report.json schemaVersion (if a scan report was found in Check 2):
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

Validate config.yaml version:
  Expected version: "1.0" (current known version).
  If version is missing:
    Print: "Note: config.yaml has no version field. It may predate version tracking."
    Continue.
  If version matches:
    Continue silently.
```

---

## Phase 1 — Load Data

Read the preferred data source and extract coverage metrics, per-file data, and configuration.

### Execution Steps

1. **Read the preferred data source** — Load the file identified in Pre-Flight Check 2:

   **From run-results.json:**
   ```
   Read: .bestest/reports/run-<timestamp>.json
   Extract:
     - coverage object: { collected, lines, branches, functions, statements }
     - configSnapshot: for framework and path configuration
     - timestamp: for report metadata
   If coverage.collected === false:
     Print: "Run results exist but coverage was not collected."
     Print: "Falling back to scan report if available."
     Attempt to load most recent scan report instead.
     If scan report also unavailable:
       Fall back to static analysis mode (see Error Handling scenario 2).
   ```

   **From scan report:**
   ```
   Read: .bestest/reports/scan-<timestamp>.json
   Extract:
     - coverage object: { lines, branches, functions, statements }
     - gaps[] array: pre-computed gaps from prior scan
     - configSnapshot: for framework and path configuration
     - testInventory[]: for existing test awareness
     - timestamp: for report metadata
   ```

   **From language-specific raw coverage artifacts** (when framework is known from config):
   ```
   Determine framework from config.yaml framework field.

   Python (framework: pytest):
     Read: .bestest/reports/coverage.json
     This is the coverage.py JSON output produced by pytest-cov with --cov-report=json.
     Extract:
       - totals.covered_lines, totals.num_statements → lines
       - totals.covered_branches, totals.num_branches → branches
       - totals.percent_covered → lines.pct
       - totals.percent_covered_branches → branches.pct
       - files{} object → per-file coverage (see Step 3)
     Functions are not available from coverage.py — set functions to { total: 0, covered: 0, pct: 0.0 }.

   Java (framework: junit5):
     Determine build tool from config.yaml junit5.build_tool (default: gradle).
     Gradle: Read build/reports/jacoco/test/jacocoTestReport.xml
     Maven: Read target/site/jacoco/jacoco.xml
     This is the JaCoCo XML report.
     Extract:
       - Top-level <report><counter type="LINE"> → lines
       - <counter type="BRANCH"> → branches
       - <counter type="METHOD"> → functions
       - <counter type="INSTRUCTION"> → statements (JaCoCo uses INSTRUCTION as closest proxy)
       - <package>/<class>/<method><counter> → per-file coverage (see Step 3)

   Go (framework: go_testing):
     Read: .bestest/reports/go-coverage.out
     This is the Go coverage profile produced by go test -coverprofile.
     Parse with: go tool cover -func=.bestest/reports/go-coverage.out
     Extract:
       - "total: (statements) X%" line → lines.pct
       - Per-function entries → per-file coverage (see Step 3)
     Branches are not directly available from Go coverage — set to { total: 0, covered: 0, pct: 0.0 }.
     Functions are inferred from go tool cover -func output entries with >0% coverage.
   ```

2. **Extract aggregate coverage metrics** — Parse the `coverage` object into a normalized structure:

   ```json
   {
     "lines": { "total": 1842, "covered": 1523, "pct": 82.7 },
     "branches": { "total": 312, "covered": 234, "pct": 75.0 },
     "functions": { "total": 198, "covered": 167, "pct": 84.3 },
     "statements": { "total": 2104, "covered": 1756, "pct": 83.5 }
   }
   ```

   All percentage values rounded to one decimal place.

3. **Extract per-file coverage** — When the data source provides per-file breakdowns, build a map:

   ```
   perFileCoverage: Map<relativePath, { lines: { total, covered, pct }, branches: { total, covered, pct }, functions: { total, covered, pct }, statements: { total, covered, pct } }>
   ```

   Source-specific parsing strategies:

   **JavaScript/TypeScript (Vitest/Jest — Istanbul format):**
   From `coverage-summary.json` (embedded in run-results.json or standalone). Each file entry has `{ lines, branches, functions, statements }` with `{ total, covered, pct }`. Path keys are relative from project root.

   **Python (pytest-cov — coverage.py JSON):**
   From `.bestest/reports/coverage.json`. The `files` object maps absolute paths to per-file data:
   ```
   "files": {
     "/abs/path/src/utils.py": {
       "executed_lines": [1, 2, 5, 8],
       "summary": {
         "covered_lines": 15,
         "num_statements": 20,
         "percent_covered": 75.0,
         "covered_branches": 8,
         "num_branches": 12,
         "percent_covered_branches": 66.7,
         "missing_lines": 5,
         "excluded_lines": 0
       }
     }
   }
   ```
   Map each file entry:
   - Convert absolute path to relative from project root.
   - `summary.covered_lines` / `summary.num_statements` → lines.
   - `summary.covered_branches` / `summary.num_branches` → branches.
   - Functions: `{ total: 0, covered: 0, pct: 0.0 }` — not available from coverage.py JSON.
   - Statements: use same values as lines (coverage.py treats statements ≈ lines).

   **Java (JUnit 5 — JaCoCo XML):**
   From `build/reports/jacoco/test/jacocoTestReport.xml` (Gradle) or `target/site/jacoco/jacoco.xml` (Maven). JaCoCo XML structure:
   ```xml
   <report name="Project">
     <package name="com/example/service">
       <class name="com/example/service/PaymentService" sourcefilename="PaymentService.java">
         <method name="processPayment" desc="(Ljava/math/BigDecimal;)Z">
           <counter type="INSTRUCTION" missed="5" covered="15"/>
           <counter type="LINE" missed="2" covered="8"/>
           <counter type="BRANCH" missed="1" covered="3"/>
           <counter type="METHOD" missed="0" covered="1"/>
         </method>
         <counter type="LINE" missed="10" covered="40"/>
         <counter type="BRANCH" missed="4" covered="12"/>
         <counter type="METHOD" missed="2" covered="8"/>
         <counter type="INSTRUCTION" missed="15" covered="85"/>
       </class>
     </package>
   </report>
   ```
   Map each `<class>` element:
   - Build relative path from package + sourcefilename: `src/main/java/com/example/service/PaymentService.java`.
   - For each counter: `covered = covered`, `total = missed + covered`, `pct = (covered / total) * 100`.
   - counter type="LINE" → lines, "BRANCH" → branches, "METHOD" → functions, "INSTRUCTION" → statements.

   **Go (go test — coverage.out profile):**
   From `.bestest/reports/go-coverage.out`. Parse with `go tool cover -func=coverage.out` output:
   ```
   github.com/user/project/calc/discount.go:8:   CalculateDiscount   100.0%
   github.com/user/project/calc/discount.go:15:  ValidateSubtotal    85.7%
   github.com/user/project/handler/routes.go:22: HandlePayment       60.0%
   total:                                          (statements)        82.3%
   ```
   Group entries by source file (first column before `:`), then:
   - Convert module path prefix to relative path (strip module_path from config).
   - For each file: aggregate function-level percentages. Lines pct = average of function percentages weighted by statement count (or simple average if counts unavailable).
   - Branches: `{ total: 0, covered: 0, pct: 0.0 }` — not available from Go coverage.
   - Functions: count entries with >0% as covered, total entries as total.
   - Statements: use lines values as proxy (Go coverage is statement-based).

   If per-file data is not available, this map remains empty. Gap analysis in Phase 2 will use `hasTest` detection only (no percentage data for individual files).

4. **Read config coverage.target** — Extract the target threshold:

   ```
   target = config.coverage.target ?? 80
   ```

   The target is a single number representing the minimum acceptable line coverage percentage. Some projects configure per-metric targets — if `coverage.targetLines`, `coverage.targetBranches`, etc. exist, use those; otherwise, `coverage.target` applies to all four metrics.

5. **Enumerate source files** — Use `paths.src` glob to build the full source file list:

   ```
   sourceFiles = glob(paths.src) - glob(paths.ignore)
   ```

   If `--module <name>` was specified, further filter to files under that directory prefix (e.g., `--module auth` matches `src/auth/**`, `src/middleware/auth*`).

### Output

In-memory objects: `aggregateCoverage`, `perFileCoverage` map, `target`, `sourceFiles[]`, `configSnapshot`.

---

## Phase 2 — Gap Analysis

Identify source files with missing or insufficient test coverage. This phase reuses the algorithm from `spoke-scan.md` Phase 6 verbatim, ensuring consistent gap detection across `scan` and `coverage` commands.

### Execution Steps

1. **Enumerate source files** — Use the `paths.src` glob pattern from config to find all source files. Apply `paths.ignore` exclusions. Already done in Phase 1 step 5.

   ```
   Files matching: paths.src (e.g., "src/**/*.{ts,tsx}")
   Excluding: paths.ignore (e.g., "**/node_modules/**", "**/dist/**")
   Result: sourceFiles[]
   ```

2. **Cross-reference with test files** — For each source file, determine if a corresponding test file exists using naming convention matching:

   **JavaScript/TypeScript (Vitest/Jest):**

   | Source File | Expected Test Files |
   |-------------|-------------------|
   | `src/utils/format.ts` | `src/utils/format.test.ts`, `src/utils/format.spec.ts` |
   | `src/components/Button.tsx` | `src/components/Button.test.tsx`, `src/components/Button.spec.tsx` |
   | `src/services/payment.ts` | `src/services/payment.test.ts`, `src/services/payment.spec.ts` |

   Also check common test directory patterns:
   - `__tests__/format.test.ts` adjacent to the source file
   - `test/utils/format.test.ts` at the project root

   **Python (pytest):**

   | Source File | Expected Test Files |
   |-------------|-------------------|
   | `src/utils/format.py` | `tests/test_format.py`, `tests/unit/test_format.py`, `src/utils/test_format.py` |
   | `src/services/payment.py` | `tests/test_payment.py`, `tests/unit/test_payment.py`, `src/services/test_payment.py` |
   | `src/models/user.py` | `tests/test_user.py`, `tests/unit/test_user.py`, `src/models/test_user.py` |

   Also check:
   - `tests/` directory with `test_*.py` prefix convention
   - `tests/unit/` and `tests/integration/` subdirectories
   - `conftest.py` files indicate active test directories (check siblings)

   **Java (JUnit 5):**

   | Source File | Expected Test Files |
   |-------------|-------------------|
   | `src/main/java/com/example/service/PaymentService.java` | `src/test/java/com/example/service/PaymentServiceTest.java` |
   | `src/main/java/com/example/utils/Formatter.java` | `src/test/java/com/example/utils/FormatterTest.java` |
   | `src/main/java/com/example/model/User.java` | `src/test/java/com/example/model/UserTest.java` |

   Convention: test files mirror the source path under `src/test/java/` with `Test` suffix appended to the class name. Also check for `*Tests.java` and `*IT.java` (integration test) variants.

   **Go (go_testing):**

   | Source File | Expected Test Files |
   |-------------|-------------------|
   | `calc/discount.go` | `calc/discount_test.go` |
   | `handler/routes.go` | `handler/routes_test.go` |
   | `internal/service/payment.go` | `internal/service/payment_test.go` |

   Convention: Go mandates `_test.go` suffix in the same directory as the source file. No alternative naming is valid — if `*_test.go` does not exist alongside the source, there are no tests for that file. Black-box test files use `package_test` suffix but remain in the same directory.

3. **Check per-file coverage** — For files with corresponding tests, look up the per-file coverage data from Phase 1:

   - If Phase 1 produced real per-file coverage: use the per-file line coverage percentage.
   - If Phase 1 has no per-file data but a scan report was the source: use `gaps[].coverage` values from the scan report.
   - If no per-file data is available: files with tests get `hasTest: true` but `coverage: 0.0` (unknown, not zero).

4. **Assign priority** — For each source file, determine a priority level using the 4-tier table:

   | Priority | Criteria |
   |----------|----------|
   | `critical` | Source file has **no test file** AND is imported by 5+ other files (high impact radius). Also applies to: entry points (`main.ts`, `index.ts` at package root), authentication/security modules, payment processing modules. |
   | `high` | Source file has **no test file** AND is imported by 2–4 files. OR: file has a test but coverage < 30% AND is imported by 3+ files. |
   | `medium` | Source file has a test but coverage < 60%. OR: no test and imported by 0–1 files. |
   | `low` | Source file has a test but coverage < 80%. OR: file is a type-only module (`*.d.ts`, files with only `type` and `interface` exports), constant file, or configuration file with low complexity. |

   Import count data comes from:
   - The StackProfile's dependency graph when available (`.bestest/state/stack-profile.json`)
   - Simple `grep -r "from.*'{sourceFile}'" --include="*.ts"` fallback when StackProfile is absent

   Module type heuristics enhance priority:
   - Files matching `auth*`, `login*`, `permission*`, `security*` → elevated one tier
   - Files matching `payment*`, `checkout*`, `billing*` → elevated one tier
   - Files matching `*.d.ts`, `types.ts`, `constants.ts` → low priority
   - Entry points (`index.ts`, `main.ts` at package root) → critical if untested

   **Language-specific module type heuristics:**

   Python:
   - Entry points: `__main__.py`, `app.py`, `main.py`, `wsgi.py`, `asgi.py` → critical if untested
   - Security: `auth*.py`, `permissions.py`, `middleware.py` → elevated one tier
   - Payment: `payment*.py`, `billing*.py`, `checkout*.py` → elevated one tier
   - Low priority: `__init__.py` (empty or import-only), `conftest.py`, `constants.py`, `types.py`
   - Framework indicators: `models.py`, `views.py`, `serializers.py` (Django), `routes.py` (FastAPI/Flask) → medium if untested
   - Import count via: `grep -r "from.*{module}" --include="*.py"` or `grep -r "import.*{module}" --include="*.py"`

   Java:
   - Entry points: `Application.java`, `*Application.java` (Spring Boot), `Main.java` → critical if untested
   - Security: `*Security*.java`, `*Auth*.java`, `*Filter.java` (servlet filters) → elevated one tier
   - Payment: `*Payment*.java`, `*Billing*.java`, `*Checkout*.java` → elevated one tier
   - Low priority: `*Config.java` (Spring @Configuration), `*Constants.java`, `*Dto.java` / `*Request.java` / `*Response.java` (pure data classes)
   - Service layer: `*Service.java`, `*ServiceImpl.java` → high if untested
   - Controller layer: `*Controller.java`, `*Resource.java` → medium if untested (often tested via integration tests)
   - Import count via: `grep -r "import.*{fully.qualified.ClassName}" --include="*.java"`

   Go:
   - Entry points: `main.go`, `cmd/*/main.go` → critical if untested
   - Security: `auth*.go`, `middleware*.go`, `jwt*.go` → elevated one tier
   - Payment: `payment*.go`, `billing*.go`, `checkout*.go` → elevated one tier
   - Low priority: `doc.go`, `*_string.go` (go stringer), `wire_gen.go` (generated), `*.pb.go` (protobuf generated), `mock_*.go`
   - HTTP handlers: `handler*.go`, `routes*.go`, `server.go` → medium if untested
   - Import count via: `grep -r "\"{module_path}/" --include="*.go" | grep -v vendor`

5. **Build gaps array** — For each source file that is missing a test or has insufficient coverage, create an entry matching the scan-report-schema.md `gaps[]` shape:

   ```json
   {
     "sourcePath": "src/services/payment.ts",
     "hasTest": false,
     "coverage": 0.0,
     "priority": "critical",
     "reason": "No test file found. Payment service is imported by 6 other modules — high impact radius."
   }
   ```

   Field definitions:
   - `sourcePath` (string, required): Relative path from project root
   - `hasTest` (boolean, required): Whether any test file was found for this source file
   - `coverage` (number, required): Line coverage percentage (0.0–100.0), or 0.0 if no test exists
   - `priority` (string, required): `"critical"`, `"high"`, `"medium"`, or `"low"`
   - `reason` (string, required): Human-readable explanation of why this gap exists and what testing is needed

6. **Sort gaps** — Order the gaps array by priority (critical first), then by coverage ascending within each priority level. The resulting array is directly consumable by the generate spoke's `gaps[]` input contract.

### Output

`gaps[]` array populated with all source files that lack adequate test coverage, sorted by priority then coverage ascending.

---

## Phase 3 — Target Comparison

Compare aggregate coverage metrics against the configured `coverage.target`. This phase produces a structured breakdown showing which metrics meet, approach, or miss the target.

### Execution Steps

1. **Per-metric breakdown** — For each of the four coverage metrics (lines, branches, functions, statements), compute the delta against target:

   ```
   For each metric in [lines, branches, functions, statements]:
     actual = aggregateCoverage[metric].pct
     target = coverage.target (or metric-specific target if configured)
     delta = actual - target
   ```

   **Null metric handling:** Some languages do not report all four metrics. When a metric has `total: 0` and `covered: 0` (indicating the tool does not collect that metric, not that coverage is zero), exclude it from target comparison:
   - Python (coverage.py): `functions` is always `{ total: 0, covered: 0, pct: 0.0 }`. Skip function target comparison. Only compare lines, branches, and statements.
   - Go (go test -cover): `branches` is always `{ total: 0, covered: 0, pct: 0.0 }`. Skip branch target comparison. `functions` may be inferred from `go tool cover -func` but is approximate. Compare lines, functions, and statements.
   - Java (JaCoCo) and JavaScript/TypeScript (Istanbul): all four metrics are typically available. No skipping needed.

   When a metric is skipped due to null data, report it as `status: "n/a"` in the target comparison object. These metrics do not affect overall status computation.

2. **Classify each metric** — Assign a status based on the delta:

   | Status | Criteria | Indicator |
   |--------|----------|-----------|
   | `met` | actual >= target | ✅ |
   | `partial` | actual >= target - 5 (within 5% of target) | ⚠️ |
   | `unmet` | actual < target - 5 (>= 5% below target) | ❌ |
   | `n/a` | metric skipped due to null data (total: 0) | — |

3. **Compute overall status** — Determine the project's overall coverage status:

   | Overall Status | Criteria |
   |---------------|----------|
   | `all-met` | All non-skipped metrics are `met` |
   | `partial` | At least one non-skipped metric is `partial` and none are `unmet` |
   | `not-met` | At least one non-skipped metric is `unmet` |

   Metrics with `n/a` status are excluded from overall status computation.

4. **Build target comparison object** — Assemble the structured comparison:

   ```json
   {
     "target": 80,
     "overall": "not-met",
     "metrics": {
       "lines": { "actual": 82.7, "target": 80, "delta": 2.7, "status": "met" },
       "branches": { "actual": 75.0, "target": 80, "delta": -5.0, "status": "unmet" },
       "functions": { "actual": 84.3, "target": 80, "delta": 4.3, "status": "met" },
       "statements": { "actual": 83.5, "target": 80, "delta": 3.5, "status": "met" }
     }
   }
   ```

### Output

`targetComparison` object with overall status, per-metric breakdown with actual/target/delta/status.

---

## Phase 4 — Report

Write the structured coverage report to disk and print a console summary.

### Execution Steps

1. **Assemble the report** — Combine all data from Phases 1–3 into the final coverage report:

   ```json
   {
     "timestamp": "<ISO 8601 of report completion>",
     "configSnapshot": "<from Phase 1>",
     "targetComparison": "<from Phase 3>",
     "gaps": "<from Phase 2>",
     "summary": {
       "totalGaps": 23,
       "byPriority": {
         "critical": 3,
         "high": 7,
         "medium": 9,
         "low": 4
       },
       "coverageDeltas": {
         "lines": { "actual": 82.7, "target": 80, "delta": 2.7, "status": "met" },
         "branches": { "actual": 75.0, "target": 80, "delta": -5.0, "status": "unmet" },
         "functions": { "actual": 84.3, "target": 80, "delta": 4.3, "status": "met" },
         "statements": { "actual": 83.5, "target": 80, "delta": 3.5, "status": "met" }
       },
       "untestedFiles": 10,
       "underCoveredFiles": 13
     }
   }
   ```

   Field definitions:
   - `timestamp` (string): ISO 8601 datetime of report generation
   - `configSnapshot` (object): Snapshot of config.yaml at analysis time
   - `targetComparison` (object): Per-metric comparison against targets (from Phase 3)
   - `gaps` (array): All coverage gaps sorted by priority (from Phase 2)
   - `summary.totalGaps` (integer): Total number of gaps
   - `summary.byPriority` (object): Gap count per priority level
   - `summary.coverageDeltas` (object): Per-metric actual/target/delta/status
   - `summary.untestedFiles` (integer): Count of files with `hasTest: false`
   - `summary.underCoveredFiles` (integer): Count of files with tests but below target coverage

2. **Write JSON report** — Write to `.bestest/reports/coverage-<timestamp>.json`:

   - Timestamp format: `YYYYMMDDTHHmmssZ` (compact ISO 8601, e.g., `coverage-20240715T143045Z.json`)
   - Ensure `.bestest/reports/` directory exists before writing.
   - **Never overwrite or delete existing reports.** All prior reports are preserved for trend analysis.

3. **Print console summary** — Display a human-readable summary (skip if `--format json` was specified):

   ```
   ## bestest coverage analysis

   ### Target vs Actual
   | Metric      | Actual | Target | Delta | Status |
   |-------------|--------|--------|-------|--------|
   | Lines       | 82.7%  | 80%    | +2.7  | ✅ MET |
   | Branches    | 75.0%  | 80%    | -5.0  | ❌ NOT MET |
   | Functions   | 84.3%  | 80%    | +4.3  | ✅ MET |
   | Statements  | 83.5%  | 80%    | +3.5  | ✅ MET |

   Overall: NOT MET — branches coverage is 5.0% below target.

   ### Coverage Gaps
   Total: 23 gaps found
   - Critical: 3 | High: 7 | Medium: 9 | Low: 4
   - Untested files: 10 | Under-covered files: 13

   ### Top Critical Gaps
   1. src/services/payment.ts — No test file. Imported by 6 modules.
   2. src/middleware/auth.ts — No test file. Authentication module.
   3. src/lib/validator.ts — 23.5% coverage. Imported by 4 modules.

   ### Gaps by Module
   {If import graph data is available from StackProfile:}
   - src/services/ — 5 gaps (2 critical, 2 high, 1 medium)
   - src/utils/ — 4 gaps (0 critical, 1 high, 3 medium)
   - src/components/ — 8 gaps (1 critical, 3 high, 3 medium, 1 low)
   - src/middleware/ — 3 gaps (0 critical, 1 high, 2 medium)
   - src/types/ — 3 gaps (0 critical, 0 high, 0 medium, 3 low)

   ### Report
   - Written to: .bestest/reports/coverage-{timestamp}.json
   ```

   Module grouping is derived from the first two path segments of each `sourcePath`. When the StackProfile provides an import graph, modules can be identified by package or namespace boundaries instead.

### Output

| Artifact | Location | Purpose |
|----------|----------|---------|
| Coverage report | `.bestest/reports/coverage-<timestamp>.json` | Structured coverage data with gaps, target comparison, and summary |
| Console summary | Terminal | Human-readable target comparison, gap breakdown, top critical gaps, module grouping |

---

## Phase 5 — Auto-Chain to Generate

Present a HITL (human-in-the-loop) gate offering to invoke the generate spoke for user-selected gaps. This phase only runs when gaps were found (skipped when all targets are met).

### HITL Gate Presentation

After printing the console summary, present the auto-chain options:

```
### Next Steps — Address Coverage Gaps

Found {totalGaps} coverage gaps ({critical + high} critical/high priority).

Options:
  1. /bestest generate --untested     — Generate tests for all {untestedFiles} files with no tests
  2. /bestest generate --critical     — Generate tests for {critical + high} critical and high priority gaps
  3. /bestest generate --target <file> — Generate tests for a specific file (you choose)
  4. Skip — Review the report and decide later

Which option would you like? [1-4]:
```

### Option Details

**Option 1: `--untested`** — Invokes the generate spoke with the `--untested` flag. The generate spoke reads `gaps[]` from the most recent scan/coverage report and targets all files where `hasTest: false`. This is the broadest option — it addresses every file without a test.

**Option 2: `--critical`** — Invokes the generate spoke with the `--critical` flag. Targets only files with `priority: "critical"` and `priority: "high"` from the gaps array. This is the recommended starting point — it focuses effort on the highest-impact gaps.

**Option 3: `--target <file>`** — The user specifies one or more source files to target. The generate spoke is invoked with `--target <path>` for each selected file. Present the top critical gaps as selectable options:

```
Select files to generate tests for:
  [ ] src/services/payment.ts (critical — no test, imported by 6)
  [ ] src/middleware/auth.ts (critical — no test, auth module)
  [ ] src/lib/validator.ts (high — 23.5% coverage)
  [ ] src/utils/logger.ts (high — no test)
  ...
  (select one or more, then confirm)
```

**Option 4: Skip** — No further action. The coverage report is preserved for later reference.

### Auto-Chain Execution

When the user selects an option (1, 2, or 3), invoke the generate spoke:

```
The gaps[] array produced in Phase 2 is directly compatible with generate's gap consumption.
The shape matches exactly: { sourcePath, hasTest, coverage, priority, reason }.

Invoke: /bestest generate {selected-flag}
The generate spoke reads the most recent report from .bestest/reports/ (which now includes the
coverage report just written) and proceeds through its 7-phase pipeline.
```

### Data Contract

The `gaps[]` array from Phase 2 uses the same schema as `scan-report-schema.md` gaps[] and is directly consumable by the generate spoke's target selection (Phase 1). No transformation or mapping is required:

| Coverage Spoke Output | Generate Spoke Consumption | Compatibility |
|----------------------|---------------------------|---------------|
| `gaps[].sourcePath` | Target file path for test generation | Direct — same field |
| `gaps[].hasTest` | Determines `--untested` filter eligibility | Direct — same field |
| `gaps[].coverage` | Baseline for coverage delta after generation | Direct — same field |
| `gaps[].priority` | Determines `--critical` filter and processing order | Direct — same field |
| `gaps[].reason` | Context for generation (what kind of tests are needed) | Direct — same field |

---

## Metrics Update

After Phase 4 completes and all artifacts are written, update `.bestest/state/metrics.json` per the shared protocol in `references/metrics-schema.md`. The coverage spoke updates coverage data, health score, module-level breakdowns, and activity.

### Protocol

1. **Read `.bestest/state/metrics.json`** — If the file does not exist, treat as first-time creation with defaults from `metrics-schema.md`.
2. **Parse** — If parsing fails (corruption), log a warning and reinitialize with defaults plus current coverage data. **Never abort the spoke** — metrics are observability, not a gate.
3. **Validate `schemaVersion`** — Warn if MAJOR version differs; proceed if MINOR differs.
4. **Merge spoke-specific data** (see field mapping below).
5. **Recalculate derived values** — `healthScore.breakdown.coverage`, `healthScore.breakdown.freshness`, `healthScore.overall`.
6. **Write back** — Atomic write (write to temp file, then rename).
7. **Update `config.yaml`** — Set `state.last_metrics` to current ISO 8601 timestamp.

### Fields Updated by spoke-coverage

| Metrics Section | Source Data | Merge Logic |
|----------------|------------|-------------|
| `coverage.current` | Phase 1 aggregate coverage | Replace with latest coverage snapshot (`lines`, `branches`, `functions`, `statements`). |
| `coverage.trend[]` | `coverage.current` after update | Append new coverage snapshot with timestamp. Evict oldest entries exceeding `trendMaxLength` (50). |
| `healthScore.breakdown.coverage` | `coverage.current.lines / coverage.target` | Recalculate. Cap at 1.0. |
| `healthScore.breakdown.freshness` | Current time vs `lastUpdated` | Set to 1.0 (just updated). |
| `healthScore.overall` | Average of non-null breakdown scores | Recalculate. |
| `modules.entries[]` | Phase 2 per-file coverage data | Update coverage for modules present in the gaps analysis. Replace entries for modules with new data; leave existing entries for untouched modules unchanged. |
| `activity[]` | Coverage summary | Append `{ timestamp, spoke: "spoke-coverage", action: "coverage", summary: "{totalGaps} gaps found ({overallStatus}), {linesPct}% lines coverage" }`. Evict oldest entries exceeding `activityMaxLength` (200). |
| `lastUpdated` | Current time | Set to current ISO 8601 timestamp. |

### Bounded Array Eviction

All arrays use FIFO eviction: append new entry to end, then remove from beginning if length exceeds `*maxLength`. See `metrics-schema.md` → Bounded Array Eviction for the canonical algorithm.

---

## Error Handling

### 1. No data source found

**Trigger**: No `run-results.json` exists in `.bestest/reports/`, no scan report exists, and no coverage data is available.

**Response**:
```
Print: "No coverage data found."
Print: "Coverage analysis requires test execution data. Run one of:"
Print: "  1. /bestest run --coverage    — Execute tests with coverage collection"
Print: "  2. /bestest scan              — Full audit including coverage analysis"
Print: "After running one of these, re-run /bestest coverage to see gap analysis."
```
Exit. No report is written.

### 2. Coverage not collected (static analysis mode)

**Trigger**: `run-results.json` exists but `coverage.collected === false`, and no scan report is available as fallback.

**Response**:
```
Print: "Warning: Coverage was not collected during the last run."
Print: "Falling back to static analysis mode — gap detection uses hasTest only."
Print: "To get accurate coverage percentages, run:"
Print: "  /bestest run --coverage"
Print: "  /bestest config set coverage.enabled true"
```

Static analysis mode:
- All gap detection via file naming convention (hasTest boolean only).
- No per-file coverage percentages — `coverage` field is `0.0` for all files with tests (unknown, not zero) and `0.0` for files without tests (accurate).
- Priority assignment uses import count and module type heuristics only (no coverage data to refine priority).
- Target comparison is not possible — print warning and skip Phase 3.
- Report includes `analysisMode: "static_analysis"` to distinguish from real coverage data.

### 3. Missing config

**Trigger**: `.bestest/config.yaml` does not exist or is invalid.

**Response**:
```
Print: ".bestest/config.yaml is missing or invalid."
Print: "Coverage analysis requires configuration with coverage.target and paths.src."
Print: "Run /bestest init to create a valid configuration."
```
Exit. Cannot proceed without config.

### 4. Monorepo

**Trigger**: `config.yaml` has `monorepo.enabled: true`.

**Response**:
- Run gap analysis per package listed in `monorepo.packages`.
- Combine results into a single unified gaps[] array with package-prefixed paths (e.g., `packages/ui/src/Button.tsx`).
- Target comparison uses aggregate coverage across all packages.
- Console summary includes per-package breakdown.
- Auto-chain generates tests per-package, respecting each package's test directory and framework config.

### 5. Large codebase (>500 source files)

**Trigger**: Source file enumeration returns more than 500 files.

**Response**:
```
Print: "Large codebase detected: {N} source files."
Print: "Full analysis may take time. Consider:"
Print: "  1. /bestest coverage --module <name>  — Focus on a specific module"
Print: "  2. Narrow paths.src in config.yaml    — Exclude generated or vendor code"
Print: "  3. Add patterns to paths.ignore        — Skip non-critical directories"
```
Continue with full analysis. For the console summary, sample the top 5 directories by gap count and suggest module-level analysis for the rest. The JSON report always contains the complete gaps array.

### 6. All targets met

**Trigger**: Phase 3 determines overall status is `all-met` — all four metrics meet or exceed the configured target.

**Response**:
```
Print: "## bestest coverage analysis"
Print: ""
Print: "### All Coverage Targets Met! 🎉"
Print: ""
Print: "| Metric      | Actual | Target | Delta |"
Print: "|-------------|--------|--------|-------|"
Print: "| Lines       | {pct}% | {tgt}%  | +{d}  |"
Print: "| Branches    | {pct}% | {tgt}%  | +{d}  |"
Print: "| Functions   | {pct}% | {tgt}%  | +{d}  |"
Print: "| Statements  | {pct}% | {tgt}%  | +{d}  |"
Print: ""
Print: "No auto-chain to generate is needed. Your test coverage meets all targets."
Print: ""
Print: "Found {totalGaps} low-priority gaps that could still be improved."
Print: "Run /bestest coverage --module <name> for detailed per-module analysis."
```
Skip Phase 5 (auto-chain). The report is still written to disk for record-keeping.

### 7. pytest-cov not installed (Python)

**Trigger**: Framework is `pytest`, raw coverage artifact `.bestest/reports/coverage.json` does not exist, and no run-results.json is available.

**Response**:
```
Print: "No coverage data found for Python project."
Print: "pytest-cov is required for coverage collection with pytest."
Print: "Install and run:"
Print: "  pip install pytest-cov"
Print: "  /bestest run --coverage"
Print: "Then re-run /bestest coverage."
```
Exit. Cannot proceed without coverage data.

### 8. JaCoCo report not found (Java)

**Trigger**: Framework is `junit5`, no run-results.json available, and JaCoCo XML report is missing at both expected paths:
- Gradle: `build/reports/jacoco/test/jacocoTestReport.xml`
- Maven: `target/site/jacoco/jacoco.xml`

**Response**:
```
Print: "No JaCoCo coverage report found."
If build_tool is gradle:
  Print: "Expected at: build/reports/jacoco/test/jacocoTestReport.xml"
  Print: "Generate it with: ./gradlew test jacocoTestReport"
Else (maven):
  Print: "Expected at: target/site/jacoco/jacoco.xml"
  Print: "Generate it with: ./mvnw test jacoco:report"
Print: "Or run: /bestest run --coverage"
```
Exit. Cannot proceed without coverage data.

### 9. Go coverage profile not found

**Trigger**: Framework is `go_testing`, no run-results.json available, and `.bestest/reports/go-coverage.out` does not exist.

**Response**:
```
Print: "No Go coverage profile found."
Print: "Expected at: .bestest/reports/go-coverage.out"
Print: "Generate it with:"
Print: "  go test -coverprofile=.bestest/reports/go-coverage.out ./..."
Print: "Or run: /bestest run --coverage"
```
Exit. Cannot proceed without coverage data.

### 10. Mixed-language monorepo with multiple frameworks

**Trigger**: `monorepo.enabled: true` and packages use different frameworks (e.g., packages/api uses pytest, packages/ui uses vitest).

**Response**:
- Run coverage analysis per package, dispatching to the correct language-specific parser based on each package's `config.yaml` framework field.
- Each package's metrics use its own null metric handling (e.g., the Python package skips functions, the Go package skips branches).
- Combine into a unified report with per-package sections.
- Overall status considers all packages — `all-met` only when every package's non-skipped metrics meet targets.

---

## Downstream Reference

### Output Contracts

#### Coverage Report Schema

Written to `.bestest/reports/coverage-<timestamp>.json`. The report is self-contained — no cross-references to other files are needed to interpret it.

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string (ISO 8601) | When the analysis was generated |
| `configSnapshot` | object | Config state at analysis time (same shape as config-schema.md) |
| `targetComparison` | object | Per-metric comparison: `{ target, overall, metrics: { lines, branches, functions, statements } }` where each metric has `{ actual, target, delta, status }` |
| `gaps` | array | Coverage gaps matching scan-report-schema.md gaps[] shape (see below) |
| `summary` | object | `{ totalGaps, byPriority: { critical, high, medium, low }, coverageDeltas: { lines, branches, functions, statements } each with { actual, target, delta, status }, untestedFiles, underCoveredFiles }` |

#### gaps[] Shape

The gaps array uses the identical schema defined in `scan-report-schema.md`:

```json
{
  "sourcePath": "src/services/payment.ts",
  "hasTest": false,
  "coverage": 0.0,
  "priority": "critical",
  "reason": "No test file found. Payment service is imported by 6 other modules — high impact radius."
}
```

Field types: `sourcePath` (string), `hasTest` (boolean), `coverage` (number, 0.0–100.0), `priority` (`"critical"` | `"high"` | `"medium"` | `"low"`), `reason` (string).

#### Auto-Chain Options Mapping

| Coverage Option | Generate Invocation | gaps[] Filter |
|----------------|-------------------|---------------|
| `--untested` | `/bestest generate --untested` | `gaps.filter(g => !g.hasTest)` |
| `--critical` | `/bestest generate --critical` | `gaps.filter(g => g.priority === 'critical' || g.priority === 'high')` |
| `--target <file>` | `/bestest generate --target <file>` | `gaps.filter(g => g.sourcePath === file)` |

### Important Notes

- **The coverage spoke does NOT re-run coverage.** It reads existing data from `run-results.json` or scan reports only. To refresh coverage data, run `/bestest run --coverage` or `/bestest scan` first.
- **Report retention:** All coverage reports are preserved — the coverage command never deletes previous reports. Downstream tooling can compare consecutive reports for coverage trend analysis.
- **Cross-file consistency:** The coverage spoke references the coverage field contract from `spoke-run.md`, coverage configuration from `config-schema.md`, and gap targeting modes from `spoke-generate.md`. The `gaps[]` shape is defined in `scan-report-schema.md` and shared across scan, coverage, and generate spokes.
- **Framework independence:** The coverage spoke is framework-agnostic at the analysis layer — it reads structured data regardless of whether Vitest, Jest, pytest-cov, JaCoCo, or `go test -coverprofile` produced it. Framework-specific parsing (coverage.py JSON, JaCoCo XML, Go coverage.out) is handled in Phase 1 Step 3. The unified metrics shape ensures all downstream phases (gap analysis, target comparison, report) are language-independent.
- **Language dispatch:** The spoke dispatches on `config.yaml` `framework` field to select the correct data source and parsing strategy. This matches the dispatch pattern used in `spoke-run.md` and `spoke-scan.md`.
- **Null metric convention:** When a language's coverage tool does not report a metric (Python: functions, Go: branches), the metric is set to `{ total: 0, covered: 0, pct: 0.0 }` in the unified shape. Phase 3 skips these metrics in target comparison rather than treating them as 0% coverage. This prevents false negatives where a project "fails" a target for a metric the tool cannot measure.
