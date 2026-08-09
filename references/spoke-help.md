# /bestest help

## Purpose

Display available commands, quick-start guidance, and a summary of the current project's testing configuration. The `help` command is a read-only terminal spoke that works with or without `.bestest/` initialized — when `.bestest/` exists, it augments the output with the current config summary and status hints.

Use `/bestest help` to see all available commands with one-line descriptions, or `/bestest help <command>` to display detailed usage for a specific command.

## Prerequisites

- **None required** — The help spoke is always available, even before `/bestest init` has been run.
- `.bestest/config.yaml` is **optional** — when present, help displays a config summary section with the active framework, coverage target, and language.

## Pre-Flight Checks

No pre-flight checks are required. The help spoke is designed to be the entry point for new users and must not fail due to missing infrastructure.

> See **references/pre-flight-protocol.md** for the standard 3-step `.bestest/` validation pattern and spoke-specific variants.

### 1. Check for `.bestest/` (optional context)

```
If .bestest/ exists AND .bestest/config.yaml is valid YAML:
  Set hasConfig = true
  Parse and extract: framework, language, coverage.target, coverage.enabled, e2e.enabled, ci.enabled
Else:
  Set hasConfig = false
```

### 2. Check for StackProfile (optional context)

```
If .bestest/state/stack-profile.json exists:
  Set hasProfile = true
  Extract: languages[0].name, detected frameworks
Else:
  Set hasProfile = false
```

---

## Workflow

### General Help (`/bestest help`)

When invoked without a specific command argument, display the full command reference with quick-start guidance.

#### Step 1: Display banner

```
bestest — Enterprise-grade testing architect

Commands:
```

### Getting Started

New to bestest? Follow this path:

```
1. /bestest           → Auto-detects your project and runs init or scan
2. /bestest scan      → Deep audit of your current test state
3. /bestest generate  → Generate tests for uncovered files
4. /bestest run       → Execute all tests
5. /bestest fix       → Fix any failing tests
```

Tip: Just type `/bestest` with no arguments — it will automatically run init (first time) or scan (subsequent runs) based on your project state.

#### Step 2: Display command table

| Command | Description |
|---------|-------------|
| `init` | Full audit + scaffold of testing infrastructure |
| `config` | View and modify `.bestest/config.yaml` |
| `scan` | Deep audit of current test state |
| `generate` | AI test generation with verification loop |
| `run` | Execute test suites with result capture |
| `fix` | Fix failing and flaky tests |
| `coverage` | Coverage gap analysis |
| `report` | Generate test reports |
| `doctor` | Health check test infrastructure |
| `expand` | Add new test types |
| `migrate` | Migrate test frameworks |
| `ci` | Generate CI pipelines |
| `help` | Show this help message |
| `explain` | Explain testing architecture decisions |
| `status` | Show current test health summary |
| `version` | Show bestest version and environment info |

#### Step 3: Display config summary (if `.bestest/` exists)

If `hasConfig` is true, display a compact configuration summary:

```
─── Current Configuration ───

  Framework:  vitest
  Language:   typescript
  Coverage:   80% target (enabled)
  E2E:        playwright
  CI:         github-actions

─── Quick Actions ───

  /bestest scan       → Run a deep audit of your test suite
  /bestest generate   → Generate tests for uncovered code
  /bestest doctor     → Health check your testing infrastructure
```

#### Step 4: Display quick-start for new users (if `.bestest/` does not exist)

If `hasConfig` is false, display onboarding guidance:

```
─── Getting Started ───

  No .bestest/ directory found. Run these commands to get started:

  1. /bestest init       → Detect your stack and scaffold testing infrastructure
  2. /bestest scan       → Audit your current test state
  3. /bestest generate   → Generate tests for uncovered code

  /bestest init will detect your language, recommend a framework,
  set coverage targets, and create a production-grade config.
```

#### Step 5: Display usage syntax

```
Usage:
  /bestest <command> [args]

  /bestest help <command>   → Detailed help for a specific command
  /bestest version          → Version and environment information
```

### Your Next Step

Based on your current state:
- No `.bestest/` directory? → Run `/bestest init`
- Have `.bestest/` but never scanned? → Run `/bestest scan`
- Scan complete, have gaps? → Run `/bestest generate --untested`
- Tests generated? → Run `/bestest run` to verify
- Tests failing? → Run `/bestest fix`
- All passing? → Run `/bestest coverage` to check coverage
- Happy with coverage? → Run `/bestest ci` to add CI pipelines
- Any issues? → Run `/bestest doctor` for a health check

### Command-Specific Help (`/bestest help <command>`)

When invoked with a specific command argument, display detailed usage for that command.

#### Step 1: Resolve the command

```
Normalize the argument:
  Accept: "gen", "g" → "generate"
  Accept: "s" → "scan"
  Accept: "r" → "run"
  Accept: "f" → "fix"
  Accept: "c" → "config"
  Accept: "cov" → "coverage"
  Accept: "rep" → "report"
  Accept: "doc" → "doctor"
  Accept: "exp" → "expand"
  Accept: "mig" → "migrate"
  Accept: "h", "?" → "help"
  Accept: "e" → "explain"
  Accept: "stat" → "status"
  Accept: "v", "ver" → "version"

If the argument does not match any known command:
  Print: "Unknown command: {arg}"
  Print: "Run /bestest help to see all available commands."
  Exit.
```

#### Step 2: Display command help

For each command, display a structured help block:

```
─── /bestest {command} ───

{purpose_description}

Usage:
  /bestest {command} {arguments_if_any}

Prerequisites:
  {list of prerequisites from the command's spoke file}

What it does:
  {brief summary of the workflow phases}

Output:
  {list of artifacts produced}

Examples:
  /bestest {command} {example_args}
  /bestest {command} {another_example}

See also:
  /bestest help {related_command}
```

**Command-specific help content:**

### init

```
─── /bestest init ───

Full audit and scaffold of testing infrastructure. Detects your stack,
recommends a framework, creates .bestest/ with config.yaml, generates
TESTING.md, and optionally scaffolds framework config files.

Usage:
  /bestest init

Prerequisites:
  None — this is the entry point command.

What it does:
  1. Detects languages and frameworks via the detection engine
  2. Recommends a test framework with an ADR
  3. Creates .bestest/ with config.yaml and stack-profile.json
  4. Generates TESTING.md with testing strategy documentation
  5. Scaffolds framework config (vitest.config.ts, etc.)

Output:
  .bestest/config.yaml       — Test configuration
  .bestest/state/stack-profile.json — Detected technology stack
  .bestest/adrs/ADR-001-*.md — Framework selection ADR
  TESTING.md                 — Living test documentation

Examples:
  /bestest init

See also:
  /bestest config
  /bestest scan
```

### config

```
─── /bestest config ───

View and modify the .bestest/config.yaml test configuration.

Usage:
  /bestest config [show] [key]         → Display configuration
  /bestest config set <key> <value>    → Update a configuration value
  /bestest config validate             → Check config for errors
  /bestest config reset                → Restore framework defaults

Prerequisites:
  .bestest/ directory with valid config.yaml (run /bestest init first)

What it does:
  - show: Displays full or single-field config
  - set: Updates a value with schema validation
  - validate: Checks all fields against the schema
  - reset: Restores defaults while preserving runtime state

Output:
  Displayed configuration or validation report
  (set and reset modify config.yaml on disk)

Examples:
  /bestest config
  /bestest config show coverage.target
  /bestest config set coverage.target 90
  /bestest config validate
  /bestest config reset

See also:
  /bestest init
  /bestest doctor
```

### scan

```
─── /bestest scan ───

Deep audit of current test state. Analyzes source files, test files,
coverage data, and configuration to produce a comprehensive report.

Usage:
  /bestest scan

Prerequisites:
  .bestest/ with config.yaml (run /bestest init first)

What it does:
  1. Validates config and framework setup
  2. Scans source and test file trees
  3. Runs coverage analysis
  4. Detects test anti-patterns
  5. Produces a scan report in .bestest/reports/

Output:
  .bestest/reports/scan-<timestamp>.json — Detailed scan report
  .bestest/state/stack-profile.json — Updated stack profile
  TESTING.md — Updated living documentation

Examples:
  /bestest scan

See also:
  /bestest init
  /bestest coverage
  /bestest doctor
```

### generate

```
─── /bestest generate ───

AI test generation with verification loop. Generates production-quality
tests for uncovered source files, verifies compilation and execution,
and produces a quality score.

Usage:
  /bestest generate [file|glob]
  /bestest generate --lang <language>

Prerequisites:
  .bestest/ with config.yaml (run /bestest init first)

What it does:
  1. Targets uncovered source files
  2. Generates tests using AI with framework-specific patterns
  3. Verifies compilation and execution
  4. Runs quality audit (assertions, anti-patterns, flakiness)
  5. Updates coverage baseline

Output:
  Generated test files in the project's test directory
  Updated TESTING.md with coverage changes

Examples:
  /bestest generate
  /bestest generate src/utils.ts
  /bestest generate "src/**/*.ts"
  /bestest generate --lang python

See also:
  /bestest scan
  /bestest run
  /bestest fix
```

### run

```
─── /bestest run ───

Execute test suites with result capture. Runs the configured test
framework and captures structured results including pass/fail counts,
timing, and failure details.

Usage:
  /bestest run [suite]          → suite: unit | integration | e2e | all | affected
  /bestest run --coverage       → Run with coverage collection

Prerequisites:
  .bestest/ with config.yaml
  Test framework must be installed (vitest, jest, pytest, etc.)

What it does:
  1. Validates framework and config
  2. Builds the test command from config
  3. Executes tests and captures output
  4. Parses results into structured report
  5. Updates .bestest/state/

Output:
  .bestest/reports/run-<timestamp>.json — Run report
  Console output with pass/fail summary

Examples:
  /bestest run
  /bestest run src/utils.test.ts
  /bestest run --coverage

See also:
  /bestest generate
  /bestest fix
  /bestest coverage
```

### fix

```
─── /bestest fix ───

Fix failing and flaky tests. Analyzes test failures, diagnoses root
causes, and applies targeted fixes with verification.

Usage:
  /bestest fix [test-file]
  /bestest fix --flaky             → Target flaky tests only (requires ≥2 full-suite run reports)

Prerequisites:
  .bestest/ with config.yaml
  At least one failing or flaky test (from /bestest run or CI)

What it does:
  1. Reads failure details from run report or executes tests
  2. Classifies failures (assertion, timeout, flaky, environment)
  3. Generates targeted fixes
  4. Verifies fixes pass
  5. Produces fix report

Output:
  Modified test files with fixes applied
  .bestest/reports/fix-<timestamp>.json — Fix report

Examples:
  /bestest fix
  /bestest fix src/utils.test.ts
  /bestest fix --flaky

See also:
  /bestest run
  /bestest doctor
  /bestest coverage
```

### coverage

```
─── /bestest coverage ───

Coverage gap analysis. Identifies uncovered files, functions, and
branches, and produces an actionable coverage report with suggestions.

Usage:
  /bestest coverage
  /bestest coverage --target 90    → Analyze against a specific target

Prerequisites:
  .bestest/ with config.yaml
  Coverage data from a recent test run

What it does:
  1. Reads coverage data from the last run
  2. Identifies uncovered files and critical gaps
  3. Computes coverage delta from baseline
  4. Produces a gap analysis report

Output:
  Console output with coverage summary and gaps
  Suggestions for /bestest generate targets

Examples:
  /bestest coverage
  /bestest coverage --target 90

See also:
  /bestest run
  /bestest scan
  /bestest generate
```

### report

```
─── /bestest report ───

Generate human-readable test reports. Produces formatted reports from
scan, run, and coverage data for sharing with the team.

Usage:
  /bestest report

Prerequisites:
  .bestest/ with config.yaml
  At least one scan or run report available

What it does:
  1. Reads available reports from .bestest/reports/
  2. Aggregates data into summary, trends, and history
  3. Generates a formatted Markdown report

Output:
  .bestest/reports/report-<timestamp>.md — Human-readable report

Examples:
  /bestest report

See also:
  /bestest scan
  /bestest run
  /bestest coverage
```

### doctor

```
─── /bestest doctor ───

Health check test infrastructure. Validates config, detects stale
dependencies, checks CI integration, and scores overall test health
across multiple dimensions.

Usage:
  /bestest doctor

Prerequisites:
  .bestest/ with config.yaml (run /bestest init first)

What it does:
  1. Validates config.yaml against the schema
  2. Checks framework installation and version
  3. Verifies test file locations match paths config
  4. Checks CI integration status
  5. Scores health across 8 dimensions
  6. Produces actionable recommendations

Output:
  Console output with health scores and recommendations
  .bestest/reports/doctor-<timestamp>.json — Health report

Examples:
  /bestest doctor

See also:
  /bestest init
  /bestest config validate
  /bestest scan
```

### expand

```
─── /bestest expand ───

Add a new test type to the project. Extends the testing strategy beyond
what init configured.

Supported types: e2e, api, mutation, contract, chaos, performance

Usage:
  /bestest expand <type>
  /bestest expand e2e
  /bestest expand api
  /bestest expand mutation

Prerequisites:
  .bestest/ with config.yaml
  Existing test infrastructure from /bestest init

What it does:
  1. Validates the requested test type
  2. Installs required dependencies
  3. Creates test directory structure and config
  4. Updates config.yaml with new test type settings
  5. Generates example tests for the new type

Output:
  New test directory and example files
  Updated config.yaml
  Updated TESTING.md

Examples:
  /bestest expand e2e
  /bestest expand api
  /bestest expand mutation

See also:
  /bestest init
  /bestest generate
  /bestest run
```

### migrate

```
─── /bestest migrate ───

Migrate test frameworks. Transforms test suites from one framework to
another using AST-aware rules with verification.

Usage:
  /bestest migrate <from> <to>
  /bestest migrate jest vitest
  /bestest migrate junit4 junit5
  /bestest migrate cypress playwright

Supported paths:
  jest → vitest         (JS/TS)
  junit4 → junit5       (Java)
  cypress → playwright  (E2E)

Prerequisites:
  .bestest/ with config.yaml
  Source framework tests must exist in the project

What it does:
  1. Validates the migration path
  2. Fetches latest target framework docs via Context7
  3. Transforms test files using AST-aware rules
  4. Updates framework config
  5. Verifies migrated tests pass
  6. Auto-fixes any failures

Output:
  Transformed test files
  Updated config.yaml with new framework
  .bestest/reports/migration-<timestamp>.json

Examples:
  /bestest migrate jest vitest
  /bestest migrate junit4 junit5 --gradual   (--gradual is JUnit4→5 only)
  /bestest migrate cypress playwright

See also:
  /bestest init
  /bestest fix
  /bestest run
```

### ci

```
─── /bestest ci ───

Generate CI pipeline workflow files for GitHub Actions, GitLab CI,
or Jenkins.

Usage:
  /bestest ci [provider]
  /bestest ci github-actions
  /bestest ci gitlab-ci
  /bestest ci jenkins

Prerequisites:
  .bestest/ with config.yaml (run /bestest init first)

What it does:
  1. Detects CI provider and project languages
  2. Fetches latest provider docs via Context7
  3. Builds per-language test commands for 4 pipeline stages
  4. Assembles the pipeline from templates
  5. Presents for human review (HITL gate)
  6. Writes the approved pipeline and updates config

Output:
  .github/workflows/test.yml  (GitHub Actions)
  .gitlab-ci.yml              (GitLab CI)
  Jenkinsfile                 (Jenkins)
  Updated config.yaml with ci.enabled and ci.provider

Examples:
  /bestest ci
  /bestest ci github-actions

See also:
  /bestest init
  /bestest run
  /bestest doctor
```

### explain

```
─── /bestest explain ───

Explain testing architecture decisions, ADRs, and framework choices.
Shows the reasoning behind bestest's recommendations and the current
project's testing strategy.

Usage:
  /bestest explain [topic]
  /bestest explain framework     → Why this framework was chosen
  /bestest explain coverage      → Coverage strategy explanation
  /bestest explain architecture  → Overall test architecture

Prerequisites:
  .bestest/ with config.yaml for full details
  Works without .bestest/ for general explanations

Examples:
  /bestest explain
  /bestest explain framework

See also:
  /bestest help
  /bestest status
```

### status

```
─── /bestest status ───

Show current test health summary. Displays coverage, last scan results,
flaky tests, CI status, and overall health score.

Usage:
  /bestest status

Prerequisites:
  .bestest/ with config.yaml and at least one scan or run report

Examples:
  /bestest status

See also:
  /bestest scan
  /bestest doctor
  /bestest coverage
```

### version

```
─── /bestest version ───

Show bestest version, skill location, and environment information.

Usage:
  /bestest version

Prerequisites:
  None

Examples:
  /bestest version

See also:
  /bestest help
  /bestest doctor
```

---

## Error Handling

### 1. Unknown command in `/bestest help <command>`

**Trigger**: The argument does not match any known command or alias.

**Response**:
```
Unknown command: {arg}
Run /bestest help to see all available commands.
```
Exit. No files read or modified.

### 2. Corrupted config.yaml during context display

**Trigger**: `.bestest/config.yaml` exists but contains invalid YAML.

**Response**:
```
Warning: .bestest/config.yaml contains invalid YAML.
Run /bestest config validate to check for errors, or /bestest config reset to restore defaults.
Displaying help without config context.
```
Continue with general help output (skip config summary section).

### 3. Corrupted stack-profile.json during context display

**Trigger**: `.bestest/state/stack-profile.json` exists but is invalid JSON.

**Response**:
```
Warning: stack-profile.json could not be parsed.
Run /bestest scan to regenerate the stack profile.
```
Continue with `hasProfile = false`. Omit profile-related context from the output.

---

## Downstream Reference

### Input Data Contracts

| Source | Fields Used | Purpose |
|--------|------------|---------|
| `config.yaml` | `framework`, `language`, `coverage.target`, `coverage.enabled`, `e2e.enabled`, `ci.enabled` | Config summary display |
| `stack-profile.json` | `languages[].name`, `languages[].frameworks` | Stack context display |

### Output Data Contracts

The help spoke produces only console output — no files are written.

### Spoke Relationships

```
spoke-help → displays command reference, optionally reads config + StackProfile
spoke-init → creates .bestest/ that help uses for context display
spoke-config → manages config.yaml that help reads for summary
spoke-scan → creates stack-profile.json and scan reports that help references
```

### See Also

- `references/config-schema.md` — Field definitions for config.yaml display
- `references/dot-bestest-schema.md` — .bestest/ directory structure reference
- `references/quick_reference.md` — Command quick reference table
