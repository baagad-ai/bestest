# /bestest explain

## Purpose

Explain testing architecture decisions, ADRs (Architecture Decision Records), framework choices, and the current project's testing strategy. The `explain` command is a read-only spoke that provides contextual answers to "why" questions about the testing setup — why a framework was chosen, why coverage is configured a certain way, why certain test patterns are recommended.

Use `/bestest explain` for a general architecture overview, or `/bestest explain <topic>` for a focused explanation of a specific topic.

## Prerequisites

- `.bestest/` directory should exist for project-specific explanations — if missing, the spoke provides general best-practice explanations without project context
- `.bestest/config.yaml` should be valid for framework and configuration explanations
- `.bestest/adrs/` directory provides ADR content for decision explanations

## Pre-Flight Checks

### 1. Check for `.bestest/` with valid config

```
If .bestest/ does not exist:
  Set hasProject = false
  Print: "No .bestest/ directory found. Showing general testing architecture guidance."
  Print: "Run /bestest init to set up project-specific context."
Else:
  Set hasProject = true

If .bestest/config.yaml exists AND is valid YAML:
  Set hasConfig = true
  Parse and extract: framework, language, coverage.target, coverage.enabled, coverage.provider
Else:
  Set hasConfig = false
```

### 2. Check for ADRs

```
If .bestest/adrs/ exists:
  List all ADR-*.md files
  Set hasADRs = true
  Set adrList = [filename for each ADR file]
Else:
  Set hasADRs = false
  Set adrList = []
```

### 3. Check for StackProfile

```
If .bestest/state/stack-profile.json exists AND is valid JSON:
  Set hasProfile = true
  Extract: languages[], detected frameworks, package managers
Else:
  Set hasProfile = false
```

### 4. Check for scan reports

```
If .bestest/reports/scan-*.json files exist:
  Set hasScanData = true
  Extract from most recent scan: test_count, coverage_pct, anti_patterns_found
Else:
  Set hasScanData = false
```

---

## Workflow

### Step 1: Parse the topic argument

Determine what the user wants explained:

```
topic = normalize(arg)

If no argument provided:
  topic = "architecture" (default to full overview)

Normalization:
  "framework" | "fw" | "test-framework" → "framework"
  "coverage" | "cov" → "coverage"
  "architecture" | "arch" | "strategy" | "overview" → "architecture"
  "adrs" | "adr" | "decisions" → "adrs"
  "flaky" | "flakiness" | "stability" → "flaky"
  "ci" | "pipeline" | "pipelines" → "ci"
  "patterns" | "pattern" | "best-practices" → "patterns"
  "config" | "configuration" → "config"
  "e2e" | "end-to-end" | "integration" → "e2e"
```

### Step 2: Route to topic explanation

#### Topic: `architecture` (default)

Display a comprehensive overview of the project's testing architecture.

```
─── Testing Architecture Overview ───

If hasProject:
  Print framework and language from config
  Print coverage target and provider
  Print test directory structure from paths config
  Print E2E status (enabled/disabled, framework)
  Print CI status (enabled/disabled, provider)

  If hasProfile:
    Print detected stack summary
    Print all detected languages and frameworks

  If hasScanData:
    Print latest scan summary (test count, coverage, health score)

  If hasADRs:
    Print: "Architecture Decision Records:"
    For each ADR:
      Print: "  - {ADR filename}: {first heading line}"

  Print: ""
  Print: "Testing Layers:"
  Print: "  1. Unit tests — {paths.test pattern}"
  Print: "  2. Integration tests — {config or detected}"
  Print: "  3. E2E tests — {e2e.framework or 'not configured'}"

Else (no project):
  Print general testing architecture guidance:
    - Testing pyramid: unit > integration > e2e
    - Configuration-as-code: .bestest/ in version control
    - Progressive complexity: init → scan → generate → verify
    - Living documentation: TESTING.md auto-updated on scan

  Print: ""
  Print: "Run /bestest init to set up project-specific architecture."
```

#### Topic: `framework`

Explain why the current test framework was chosen and how it fits the project.

```
─── Framework Choice ───

If hasConfig:
  Print: "Active framework: {config.framework}"
  Print: "Language: {config.language}"
  Print: ""

  If hasADRs:
    Find ADR-001-*.md (framework selection ADR)
    If found:
      Print the ADR content, formatted for display:
        - Context: why the decision was needed
        - Decision: what was chosen
        - Alternatives considered
        - Consequences and trade-offs
    Else:
      Print: "No framework selection ADR found."
      Print: "Run /bestest init to generate a framework recommendation with ADR."
  Else:
    Print: "No ADRs found. Run /bestest init to generate framework selection rationale."

  Print: ""
  Print: "Framework capabilities:"
  For the active framework, print relevant capabilities:
    - Vitest: ESM-native, Vite-powered, watch mode, in-source testing, workspace support
    - Jest: Mature ecosystem, snapshot testing, parallel execution, extensive plugin support
    - pytest: Fixture system, parametrize, markers, plugin ecosystem, asyncio support
    - JUnit 5: Jupiter API, parameterized tests, nested classes, extensions, parallel execution
    - Go testing: Table-driven tests, subtests, benchmarks, fuzzing, race detection

Else (no config):
  Print general framework comparison:
    - Vitest vs Jest (JS/TS)
    - pytest (Python)
    - JUnit 5 (Java)
    - Go testing (Go)
  Print: "Framework selection depends on the project's stack and requirements."
  Print: "Run /bestest init for a framework recommendation tailored to your project."
```

#### Topic: `coverage`

Explain the coverage strategy and targets.

```
─── Coverage Strategy ───

If hasConfig:
  Print: "Coverage target: {config.coverage.target}%"
  Print: "Coverage provider: {config.coverage.provider}"
  Print: "Coverage enabled: {config.coverage.enabled}"
  Print: "Reporters: {config.coverage.reporters}"
  Print: ""

  Print: "Coverage philosophy:"
  Print: "  - Coverage is a quality signal, not a target to game."
  Print: "  - {config.coverage.target}% is the minimum threshold for quality."
  Print: "  - Coverage without assertion quality is theater (bestest checks for this)."
  Print: ""

  If hasScanData:
    Print: "Current coverage: {latest_scan.coverage_pct}%"
    If current < target:
      Print: "Gap: {target - current}% to target."
      Print: "Run /bestest coverage for a detailed gap analysis."
    Else:
      Print: "✓ Coverage target met."

  Print: ""
  Print: "How coverage is enforced:"
  Print: "  - /bestest generate targets uncovered files first"
  Print: "  - /bestest run --coverage collects and reports coverage"
  Print: "  - /bestest doctor scores coverage health as a dimension"
  Print: "  - /bestest ci generates pipelines with coverage gates"

Else (no config):
  Print general coverage guidance:
    - 80% is a common default target
    - Coverage providers differ by framework (v8, istanbul, pytest-cov, etc.)
    - Mutation testing validates assertion quality
  Print: "Run /bestest init to configure coverage for your project."
```

#### Topic: `adrs`

List and explain Architecture Decision Records.

```
─── Architecture Decision Records ───

If hasADRs:
  Print: "Found {len(adrList)} ADR(s) in .bestest/adrs/:"
  Print: ""

  For each ADR file:
    Read the file
    Extract: title, status, context, decision, consequences
    Print: "ADR: {title}"
    Print: "  Status: {status}"
    Print: "  Decision: {decision_summary}"
    Print: ""

  Print: "ADRs document the 'why' behind testing decisions."
  Print: "They are created during /bestest init and updated by /bestest migrate."
Else:
  Print: "No ADRs found in .bestest/adrs/."
  Print: ""
  Print: "ADRs are created when:"
  Print: "  - /bestest init selects a framework"
  Print: "  - /bestest migrate switches frameworks"
  Print: "  - /bestest expand adds a new test type"
  Print: ""
  Print: "Run /bestest init to generate your first ADR."
```

#### Topic: `flaky`

Explain flaky test management strategy.

```
─── Flaky Test Management ───

If hasConfig:
  Print: "Flaky test retry count: {config.flaky.retries}"
  Print: ""

If hasScanData:
  Print: "Flaky tests detected: {count from scan}"
  If flaky_count > 0:
    Print: "Recent flaky tests:"
    For each flaky test:
      Print: "  - {test_name}: {failure_rate}% failure rate"
Else:
  Print: "No scan data available. Run /bestest scan to detect flaky tests."

Print: ""
Print: "Flaky test strategy:"
Print: "  1. Detection: /bestest scan identifies tests with inconsistent results"
Print: "  2. Diagnosis: /bestest fix --flaky analyzes root causes"
Print: "  3. Remediation: timing fixes, mock stabilization, retry isolation"
Print: "  4. Prevention: CI pipelines include retry policies for known-flaky stages"
Print: ""
Print: "Common flaky test causes:"
Print: "  - Timing dependencies (setTimeout, async race conditions)"
Print: "  - Shared mutable state between tests"
Print: "  - External service dependencies (network, database)"
Print: "  - Date/time-dependent logic"
Print: "  - Resource cleanup failures (teardown order)"
```

#### Topic: `ci`

Explain CI integration strategy.

```
─── CI Integration ───

If hasConfig:
  Print: "CI enabled: {config.ci.enabled}"
  Print: "CI provider: {config.ci.provider or 'not configured'}"
  Print: ""

  If config.ci.enabled:
    Print: "Pipeline architecture:"
    Print: "  Stage 1 (Fast):    Unit tests, <5 min, coverage gate"
    Print: "  Stage 2 (Medium):  Integration tests, <20 min, retry on flaky"
    Print: "  Stage 3 (Slow):    E2E tests, <60 min, retry on flaky"
    Print: "  Stage 4 (Quality): Mutation testing, nightly cron"
    Print: ""
    Print: "Coverage gate: {config.coverage.target}% threshold on Fast + Medium stages"
    Print: "Retry policy: {config.flaky.retries} retries on Medium + Slow stages"
  Else:
    Print: "CI is not currently enabled."
    Print: "Run /bestest ci to generate a CI pipeline."
Else:
  Print: "No configuration found."
  Print: "Run /bestest init to set up testing infrastructure."

Print: ""
Print: "Supported CI providers:"
Print: "  - GitHub Actions (.github/workflows/test.yml)"
Print: "  - GitLab CI (.gitlab-ci.yml)"
Print: "  - Jenkins (Jenkinsfile)"
```

#### Topic: `patterns`

Explain recommended testing patterns for the active framework.

```
─── Testing Patterns ───

If hasConfig:
  framework = config.framework

  Print: "Recommended patterns for {framework}:"

  If framework == "vitest" or framework == "jest":
    Print: "  - AAA (Arrange-Act-Assert) structure for all tests"
    Print: "  - describe/it blocks for organization"
    Print: "  - beforeEach/afterEach for setup/teardown"
    Print: "  - Mock functions for external dependencies"
    Print: "  - Snapshot testing for UI components"
    Print: "  - Parameterized tests for data-driven scenarios"

  If framework == "pytest":
    Print: "  - Fixtures for test setup and dependency injection"
    Print: "  - @pytest.mark.parametrize for data-driven tests"
    Print: "  - Custom markers for test categorization"
    Print: "  - Conftest.py for shared fixtures"
    Print: "  - tmp_path fixture for file system tests"
    Print: "  - Monkeypatch for environment and mock management"

  If framework == "junit5":
    Print: "  - @Nested classes for test organization"
    Print: "  - @ParameterizedTest for data-driven tests"
    Print: "  - @DisplayName for readable test names"
    Print: "  - Extensions over runners (JUnit 5 model)"
    Print: "  - @TempDir for file system tests"
    Print: "  - AssertJ or native assertions"

  If framework == "go_testing":
    Print: "  - Table-driven tests (t.Run subtests)"
    Print: "  - Test helpers returning setup functions"
    Print: "  - Golden file patterns for output comparison"
    Print: "  - Build tags for test categorization"
    Print: "  - Race detector (-race flag)"
    Print: "  - Benchmark tests (BenchmarkXxx functions)"

Else:
  Print: "No framework configured. Run /bestest init first."
  Print: ""
  Print: "General testing pattern principles:"
  Print: "  - Arrange-Act-Assert structure"
  Print: "  - One assertion per test (when practical)"
  Print: "  - Descriptive test names that read as specifications"
  Print: "  - Independent tests with no execution order dependency"
  Print: "  - Deterministic results — no random, no time-dependent"
```

#### Topic: `config`

Explain the current configuration and how it affects behavior.

```
─── Configuration Explanation ───

If hasConfig:
  Print: "Configuration file: .bestest/config.yaml"
  Print: ""

  Print: "Core settings:"
  Print: "  framework: {config.framework} — determines test runner, commands, and patterns"
  Print: "  language: {config.language} — affects generation, import detection, and syntax"
  Print: ""

  Print: "Coverage settings:"
  Print: "  coverage.target: {config.coverage.target}% — minimum coverage threshold"
  Print: "  coverage.provider: {config.coverage.provider} — coverage instrumentation"
  Print: "  coverage.enabled: {config.coverage.enabled} — whether coverage is collected"
  Print: ""

  Print: "Path settings:"
  Print: "  paths.test: {config.paths.test} — glob for test file discovery"
  Print: "  paths.src: {config.paths.src} — glob for source file discovery"
  Print: "  paths.ignore: {config.paths.ignore} — excluded paths"
  Print: ""

  Print: "Generation settings:"
  Print: "  generation.quality_threshold: {config.generation.quality_threshold} — min quality score"
  Print: "  generation.verify_compilation: {config.generation.verify_compilation}"
  Print: "  generation.verify_pass: {config.generation.verify_pass}"
  Print: "  generation.max_retries: {config.generation.max_retries}"
  Print: ""

  Print: "Modify with: /bestest config set <key> <value>"
  Print: "Validate with: /bestest config validate"
  Print: "Reset with: /bestest config reset"

Else:
  Print: "No configuration found."
  Print: "Run /bestest init to create .bestest/config.yaml."
```

#### Topic: `e2e`

Explain E2E testing strategy.

```
─── E2E Testing Strategy ───

If hasConfig:
  Print: "E2E enabled: {config.e2e.enabled}"
  If config.e2e.framework:
    Print: "E2E framework: {config.e2e.framework}"
  Else:
    Print: "E2E framework: not configured"

  If config.e2e.enabled:
    Print: ""
    Print: "E2E tests are configured for this project."
    If config.e2e.framework == "playwright":
      Print: "  - Playwright provides cross-browser testing"
      Print: "  - Tests run in the CI Slow stage (<60 min)"
      Print: "  - Run /bestest run --e2e to execute E2E tests locally"
    If config.e2e.framework == "cypress":
      Print: "  - Cypress provides browser-based testing"
      Print: "  - Consider migrating to Playwright for CI optimization"
  Else:
    Print: ""
    Print: "E2E tests are not enabled."
    Print: "Run /bestest expand e2e to add E2E testing."
Else:
  Print: "No configuration found."
  Print: "Run /bestest init first."

Print: ""
Print: "E2E testing principles:"
Print: "  - Test user-facing flows, not implementation details"
Print: "  - Minimize E2E tests (they are slow and brittle)"
Print: "  - Use page object models for maintainability"
Print: "  - Run E2E in CI with retry policies for flakiness"
```

### Step 3: Output footer

After any topic explanation, display:

```
─── Related Commands ───

  /bestest help        → See all available commands
  /bestest status      → Current test health summary
  /bestest doctor      → Infrastructure health check
```

---

## Error Handling

### 1. Unrecognized topic

**Trigger**: The argument does not match any known topic after normalization.

**Response**:
```
Unknown topic: "{arg}"

Available topics:
  architecture  → Testing architecture overview (default)
  framework     → Framework choice and rationale
  coverage      → Coverage strategy explanation
  adrs          → Architecture Decision Records
  flaky         → Flaky test management strategy
  ci            → CI integration strategy
  patterns      → Recommended testing patterns
  config        → Configuration explanation
  e2e           → E2E testing strategy

Usage: /bestest explain [topic]
```
Exit. No files read.

### 2. Corrupted config.yaml

**Trigger**: `.bestest/config.yaml` exists but contains invalid YAML.

**Response**:
```
Warning: .bestest/config.yaml contains invalid YAML.
Showing general explanation without project-specific context.
Fix with: /bestest config validate
```
Continue with `hasConfig = false`, providing general explanations.

### 3. Corrupted ADR file

**Trigger**: An ADR file in `.bestest/adrs/` cannot be parsed.

**Response**:
```
Warning: Could not parse {ADR filename}. Skipping.
```
Continue to the next ADR. Do not abort the entire explanation.

### 4. Missing ADR for framework topic

**Trigger**: User asks to explain framework but no ADR-001 exists.

**Response**:
```
No framework selection ADR found.
The framework was likely chosen manually or the ADR was deleted.
Run /bestest init to regenerate framework selection with ADR documentation.
```
Continue with framework capabilities explanation (from config).

---

## Downstream Reference

### Input Data Contracts

| Source | Fields Used | Purpose |
|--------|------------|---------|
| `config.yaml` | `framework`, `language`, `coverage.*`, `e2e.*`, `ci.*`, `flaky.*`, `generation.*`, `paths.*` | Project-specific explanations |
| `stack-profile.json` | `languages[]` | Stack context for architecture overview |
| `.bestest/adrs/*.md` | Full ADR content | Decision rationale display |
| `.bestest/reports/scan-*.json` | `test_count`, `coverage_pct`, `anti_patterns` | Scan data for context |

### Output Data Contracts

The explain spoke produces only console output — no files are written.

### Spoke Relationships

```
spoke-explain → reads config, ADRs, scan reports for context
spoke-init → creates .bestest/, config.yaml, and ADRs that explain references
spoke-config → manages config.yaml fields that explain describes
spoke-scan → creates scan reports that explain uses for coverage data
spoke-help → provides command reference (cross-linked)
spoke-status → provides health summary (complementary to explain)
```

### See Also

- `references/config-schema.md` — Field definitions used in config explanations
- `references/dot-bestest-schema.md` — .bestest/ directory structure for architecture explanations
- `references/ci-patterns.md` — CI pipeline patterns for ci topic explanations
- `references/anti-patterns.md` — Anti-pattern catalog referenced in patterns topic
