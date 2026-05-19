# .bestest/ Directory Schema

Complete reference for the `.bestest/` directory tree — what creates each file, what reads it, and when it's safe to delete.

---

## Directory Tree

```
.bestest/
├── config.yaml                        # Main test configuration
├── dashboard.html                     # Self-contained health dashboard (spoke-init)
├── .config.lock                       # Advisory lock file for config.yaml concurrency control
├── .gitignore                         # Ignores state/, reports/, cache/, and lock files
├── adrs/
│   └── ADR-001-test-framework.md      # Framework selection decision record
├── state/
│   ├── stack-profile.json             # Detected technology stack
│   ├── metrics.json                   # Continuous test health metrics (all spokes)
│   ├── .metrics.lock                  # Advisory lock file for metrics.json concurrency control
│   └── migration-backup.json          # Migration state checkpoint (spoke-migrate only)
└── reports/
    ├── scan-<timestamp>.json          # Scan reports (spoke-scan)
    ├── run-<timestamp>.json           # Run reports (spoke-run)
    ├── fix-<timestamp>.json           # Fix reports (spoke-fix)
    ├── doctor-<timestamp>.json        # Health check reports (spoke-doctor)
    ├── report-<timestamp>.md          # Human-readable reports (spoke-report)
    ├── migration-<timestamp>.json     # Migration reports (spoke-migrate)
    ├── junit-report.xml               # JUnit XML for CI (spoke-run, when ci.junit.enabled)
    ├── vitest-run.json                # Raw Vitest output (ephemeral)
    ├── jest-run.json                  # Raw Jest output (ephemeral)
    ├── coverage.json                  # Raw pytest-cov output (ephemeral)
    ├── go-coverage.out                # Raw Go coverage profile (ephemeral)
    ├── fix-verify.json                # Fix verification output (ephemeral)
    └── pytest-results.xml             # Raw pytest JUnit XML (ephemeral)

# At repo root (NOT inside .bestest/):
TESTING.md                             # Living test documentation
vitest.config.ts / jest.config.ts      # Framework config (JS/TS projects)
pyproject.toml [tool.pytest.ini_options]  # Framework config (Python projects)
build.gradle / pom.xml                 # Framework config (Java projects)
go.mod                                 # Framework config (Go projects)
```

---

## File-by-File Reference

### `.bestest/config.yaml`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Updated by** | `spoke-config` (set/reset), `spoke-scan` (state.last_scan), `spoke-run` (state.last_run), `spoke-fix` (state.last_fix), `spoke-doctor` (state.last_doctor), `spoke-ci` (ci.enabled, ci.provider), `spoke-expand` (test type blocks), `spoke-migrate` (framework changes) |
| **Read by** | Every spoke — config.yaml is the single source of truth for framework, paths, coverage targets, and generation settings. All spokes validate it during pre-flight checks. |
| **Schema** | Defined in `references/config-schema.md` |
| **Lifecycle** | Created once by init. Updated in place by operational spokes (timestamps, CI settings). Safe to edit manually. Reset via `/bestest config reset`. |
| **Safe to delete** | No — deleting config.yaml requires re-running `/bestest init` or manual reconstruction. |

#### Brownfield State in `config.yaml`

When `spoke-init` runs on a brownfield repo (existing test infrastructure detected), two additional fields are written to the `state` section:

| Field | Description |
|-------|-------------|
| `state.init_type` | One of `"greenfield"`, `"brownfield-coexist"`, `"brownfield-migrate"`, or `"brownfield-replace"`. Determines how operational spokes interact with existing tests. In coexist mode, scan/generate spokes treat legacy tests as first-class citizens alongside bestest-managed tests. |
| `state.existing_frameworks_preserved` | Array of legacy framework names preserved during init (e.g., `["mocha"]`, `["jest", "jasmine"]`). Only populated when `init_type` is `"brownfield-coexist"`. Empty for other init types. |

These fields are set during init and are immutable — they record the init-time decision about how to handle existing test infrastructure. Changing brownfield mode requires re-running init.

### `.bestest/.gitignore`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Template** | `references/templates/bestest-gitignore` (copied verbatim, no placeholders) |
| **Updated by** | None — static after creation |
| **Read by** | Git — ensures state/, reports/, and cache/ are not committed |
| **Ignores** | `state/`, `reports/`, `cache/` |
| **Safe to delete** | Yes, but state and reports will then be tracked by git unless the root `.gitignore` covers them. |

### `.bestest/dashboard.html`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Template** | `references/templates/dashboard.html` (copied verbatim, no placeholders) |
| **Updated by** | None — static after creation. Refreshes automatically by reading `state/metrics.json` on each page load. |
| **Read by** | Humans (opens in browser). Reads `.bestest/state/metrics.json` at runtime via `fetch('./state/metrics.json')`. |
| **Contains** | Self-contained HTML health dashboard with 9 widgets: health gauge, coverage trend, test results, flaky alerts, run history, module map, slowest tests, failure hotspots, activity feed. Uses inline SVG Lucide icons, dark/light mode, responsive layout. Zero dependencies, no server, no build step. |
| **Safe to delete** | Yes — re-run `/bestest init` to regenerate. No data loss (reads metrics.json at runtime). |

### `.bestest/adrs/`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Read by** | `spoke-doctor`, `spoke-report` — referenced for decision context |
| **Purpose** | Architecture Decision Records documenting framework and tooling choices |

#### `.bestest/adrs/ADR-001-test-framework.md`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 2 — generated alongside framework recommendation) |
| **Updated by** | None — ADRs are immutable once created |
| **Read by** | `spoke-doctor` (validates ADR exists and has required sections), `spoke-report` (includes ADR context in reports) |
| **Contains** | Status, Context, Decision, Rationale, Consequences, Alternatives Considered |
| **Safe to delete** | No — spoke-doctor will flag its absence as a health issue. |

### `.bestest/state/`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Purpose** | Machine-readable state files consumed by operational spokes. Not committed to git (covered by `.gitignore`). |

#### `.bestest/state/stack-profile.json`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 1 — Detect Stack) |
| **Updated by** | None after creation (immutable snapshot) |
| **Read by** | `spoke-scan`, `spoke-generate`, `spoke-run`, `spoke-fix`, `spoke-expand`, `spoke-ci`, `spoke-coverage`, `spoke-migrate`, `spoke-doctor`, `spoke-report` — all operational spokes read it for framework-appropriate behavior |
| **Schema** | Defined in `references/stack-profile-schema.md` |
| **schemaVersion** | `"1.3"` — set per `references/schema-contract.md`. Consumers must check schemaVersion before parsing. |
| **Contains** | Languages (with confidence scores), build tool, frameworks, package manager, test frameworks (existing/recommended), E2E framework, coverage provider, monorepo status, CI provider |
| **Brownfield fields** | When `brownfield` is `true`, the profile also contains: `testInventory` (file counts by type for gap analysis), `existingConfig` (captured legacy configuration), and `testFrameworks.legacyDetected`/`legacyFrameworks`/`inventory` from Phase 5.5 detection |
| **Lifecycle** | Created once by init. Represents a point-in-time snapshot — does not auto-update if the project changes. Re-run init (after deleting .bestest/) to regenerate. |
| **Safe to delete** | No — most spokes will emit a warning and operate with reduced capability. |

#### `.bestest/state/migration-backup.json`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-migrate` (during migration Phase 4) |
| **Updated by** | `spoke-migrate` (updated at each migration checkpoint) |
| **Read by** | `spoke-migrate` — read to resume interrupted migrations, compare before/after states |
| **Contains** | Original config snapshot, migration progress, completed steps, rollback data |
| **Safe to delete** | Yes — but doing so prevents resuming an interrupted migration. Safe to delete after migration completes successfully. |

#### `.bestest/state/metrics.json`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Updated by** | All state-changing spokes: `spoke-scan`, `spoke-run`, `spoke-fix`, `spoke-generate`, `spoke-migrate`, `spoke-doctor`, `spoke-coverage`, `spoke-report`, `spoke-config` |
| **Read by** | All operational spokes (for trend data), `spoke-doctor` (health checks), `spoke-report` (dashboard), S05 dashboard widget |
| **Schema** | Defined in `references/metrics-schema.md` |
| **schemaVersion** | `"1.0"` — set per `references/schema-contract.md`. Consumers must check schemaVersion before parsing. |
| **Contains** | Health score, coverage trends, test counts, flakiness signals, run history, module breakdown, slowest tests, failure heat map, activity log |
| **Lifecycle** | Created by init with defaults. Continuously updated by every state-changing spoke. Bounded arrays evict oldest entries (see metrics-schema.md for maxLength defaults). |
| **Corruption handling** | Pre-read validation: if parse fails, recreating with defaults + current spoke's data (graceful degradation). Never aborts the spoke. |
| **Safe to delete** | Yes — any state-changing spoke will recreate it with defaults on next invocation. Historical trend data will be lost. |

#### Lock Files

Advisory lock files for concurrency control. Created by `spoke-init`, acquired via `flock` or `mkdir` before read-modify-write cycles on the protected resources. See `references/pre-flight-protocol.md` → Concurrency Lock Protocol for the full protocol.

| File | Protects | Strategy |
|------|----------|----------|
| `.bestest/state/.metrics.lock` | `.bestest/state/metrics.json` | `flock` (primary), `mkdir` fallback |
| `.bestest/.config.lock` | `.bestest/config.yaml` | `flock` (primary), `mkdir` fallback |

**Lifecycle notes:**
- Lock files are created as empty files by `spoke-init` (Phase 4 — Scaffold).
- They are ephemeral concurrency artifacts — ignored by git via `*.lock` pattern in `.bestest/.gitignore`.
- `flock`-based locks auto-release when the holding process exits (no stale locks possible).
- `mkdir`-based locks include stale detection: locks older than 60 seconds are force-removed as stale from crashed processes.
- Safe to delete manually if no bestest instances are running.

### `.bestest/reports/`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold, creates empty directory) |
| **Updated by** | All operational spokes write report files here |
| **Read by** | `spoke-doctor`, `spoke-report`, `spoke-fix`, `spoke-coverage`, `spoke-migrate` — read historical reports for trend analysis, comparison, and diagnostics |
| **In gitignore** | Yes — reports are local artifacts, not committed |
| **Retention** | `spoke-scan` rotates `scan-*.json` files based on `config.yaml` `state.max_retained` (default: 5). Other spokes do not auto-rotate. |

#### Report File Patterns

| Pattern | Created by | Read by | Timestamp Format |
|---------|-----------|---------|------------------|
| `scan-<timestamp>.json` | `spoke-scan` | `spoke-doctor`, `spoke-report`, `spoke-coverage`, `spoke-scan` (historical comparison) | `YYYYMMDDTHHmmssZ` (e.g., `scan-20240715T143045Z.json`) |
| `run-<timestamp>.json` | `spoke-run` | `spoke-doctor`, `spoke-report`, `spoke-fix`, `spoke-coverage` | Same |
| `fix-<timestamp>.json` | `spoke-fix` | `spoke-doctor`, `spoke-report` | Same |
| `doctor-<timestamp>.json` | `spoke-doctor` | `spoke-doctor` (historical comparison) | Same |
| `report-<timestamp>.md` | `spoke-report` | User (human-readable) | Same |
| `migration-<timestamp>.json` | `spoke-migrate` | `spoke-migrate` (rollback), `spoke-report` | Same |
| `junit-report.xml` | `spoke-run` (when `ci.junit.enabled` is true) | CI systems (Jenkins, GitHub Actions, GitLab CI, CircleCI) | JUnit XML format, no timestamp — overwritten each run |

#### `.bestest/reports/junit-report.xml`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-run` (JUnit XML emission phase — between Phase 5 and Metrics Update) |
| **Config** | Controlled by `ci.junit.enabled` (default: `true`) and `ci.junit.outputPath` (default: `"reports/junit-report.xml"`) in `config.yaml` |
| **Template** | None — generated programmatically from run results |
| **Updated by** | `spoke-run` — overwritten on each run (not rotated) |
| **Read by** | CI systems (Jenkins xUnit plugin, GitHub Actions test reporter, GitLab CI JUnit report, CircleCI JUnit) |
| **Format** | De facto Apache Ant/Jenkins xUnit schema: `<testsuites>` root with `<testsuite>`, `<testcase>`, `<failure>`, `<skipped>` elements |
| **Schema** | Versioned in `references/schema-contract.md` as `junit-report-schema` (version `1.0`) |
| **Lifecycle** | Only created when `ci.junit.enabled` is `true`. Emission is non-blocking — failures are logged but do not affect spoke-run exit code. |
| **Safe to delete** | Yes — regenerated on next `spoke-run` invocation. |

#### Ephemeral Report Files

These are intermediate artifacts produced during spoke execution. They are overwritten on each invocation and not rotated.

| File | Created by | Read by | Purpose |
|------|-----------|---------|---------|
| `vitest-run.json` | `spoke-scan`, `spoke-run`, `spoke-fix` | Same spoke (Phase 3/4 parsing) | Raw `npx vitest run --reporter=json` output |
| `jest-run.json` | `spoke-scan`, `spoke-run`, `spoke-fix` | Same spoke (Phase 3/4 parsing) | Raw `npx jest --json` output |
| `coverage.json` | `spoke-scan`, `spoke-run` (Python) | `spoke-coverage` | Raw pytest-cov `--cov-report=json` output |
| `go-coverage.out` | `spoke-scan`, `spoke-run` (Go) | `spoke-coverage`, `spoke-scan`, `spoke-run` | Raw `go test -coverprofile` output |
| `pytest-results.xml` | `spoke-scan`, `spoke-run` (Python) | Same spoke (result parsing) | Raw pytest `--junitxml` output |
| `fix-verify.json` | `spoke-fix` | `spoke-fix` (verification phase) | Raw output from fix verification run |
| `pytest-output.txt` | `spoke-run` (Python, fallback) | `spoke-run` (text-based parsing) | Captured stdout when pytest-json-report unavailable |

---

## Repo Root Files

These files live at the repository root, **not** inside `.bestest/`. They are created by `spoke-init` and tracked in git.

### `TESTING.md`

| Attribute | Detail |
|-----------|--------|
| **Created by** | `spoke-init` (Phase 4 — Scaffold) |
| **Template** | `references/templates/testing-md.md` |
| **Updated by** | `spoke-scan` (populates test inventory, gaps, flaky tests), `spoke-expand` (adds new test type sections) |
| **Read by** | `spoke-doctor` (validates existence), developers (living documentation) |
| **Safe to delete** | No — spoke-doctor will flag its absence. Regenerate by deleting and re-running init. |

### Framework Configuration Files

| File | Created by | Ecosystem | Updated by |
|------|-----------|-----------|------------|
| `vitest.config.ts` | `spoke-init` | JS/TS (Vitest) | `spoke-expand` (adds setup paths for new test types) |
| `jest.config.ts` | `spoke-init` | JS/TS (Jest) | `spoke-expand` |
| `[tool.pytest.ini_options]` in `pyproject.toml` | `spoke-init` | Python | `spoke-expand` |
| `build.gradle` / `pom.xml` test blocks | `spoke-init` | Java | `spoke-migrate` (version changes) |
| `go.mod` (testify dependency) | `spoke-init` | Go | — |

---

## Spoke → File Creation Matrix

Which spokes create or modify files inside `.bestest/`:

| Spoke | config.yaml | state/ | reports/ | adrs/ | Root files | Other |
|-------|-------------|--------|----------|-------|------------|-------|
| **spoke-init** | ✅ creates | ✅ creates `stack-profile.json`, `metrics.json` | ✅ creates directory | ✅ creates ADR-001 | ✅ TESTING.md, framework config | ✅ `dashboard.html` |
| **spoke-scan** | ✅ updates `state.last_scan` | ✅ updates `metrics.json` | ✅ `scan-<ts>.json`, ephemeral files | — | — | — |
| **spoke-run** | ✅ updates `state.last_run` | ✅ updates `metrics.json` | ✅ `run-<ts>.json`, ephemeral files, `junit-report.xml` | — | — | — |
| **spoke-generate** | ✅ updates `state.last_generate` | ✅ updates `metrics.json` | — | — | ✅ creates test files | — |
| **spoke-fix** | ✅ updates `state.last_fix` | ✅ updates `metrics.json` | ✅ `fix-<ts>.json`, `fix-verify.json` | — | ✅ modifies test files | — |
| **spoke-doctor** | ✅ updates `state.last_doctor` | ✅ updates `metrics.json` | ✅ `doctor-<ts>.json` | — | — | — |
| **spoke-report** | — | ✅ updates `metrics.json` | ✅ `report-<ts>.md` | — | — | — |
| **spoke-config** | ✅ updates (set/reset) | ✅ updates `metrics.json` | — | — | — | — |
| **spoke-expand** | ✅ adds test type blocks | — | — | — | ✅ framework config updates, helper files | — |
| **spoke-ci** | ✅ updates `ci.*` | — | — | — | ✅ CI pipeline file | — |
| **spoke-migrate** | ✅ updates framework fields | ✅ `migration-backup.json`, ✅ updates `metrics.json` | ✅ `migration-<ts>.json` | — | ✅ dependency changes | — |
| **spoke-coverage** | — | ✅ updates `metrics.json` | — | — | — | — |

---

## Spoke → File Read Matrix

Which spokes read files inside `.bestest/`:

| Spoke | config.yaml | stack-profile.json | metrics.json | reports/* | adrs/* |
|-------|-------------|--------------------|--------------|----------|--------|
| **spoke-scan** | ✅ | ✅ (enriches analysis) | ✅ (trend data) | ✅ (historical comparison) | — |
| **spoke-run** | ✅ | ✅ (framework routing) | ✅ (run history) | — | — |
| **spoke-generate** | ✅ | ✅ (framework patterns) | ✅ (test counts) | ✅ (scan reports for untested files) | — |
| **spoke-fix** | ✅ | ✅ | ✅ (failure heat map) | ✅ (`run-*.json` for failures) | — |
| **spoke-doctor** | ✅ | ✅ | ✅ (health score) | ✅ (all report types) | ✅ (ADR-001 existence) |
| **spoke-report** | ✅ | ✅ | ✅ (all metrics) | ✅ (all report types) | — |
| **spoke-config** | ✅ | ✅ (smart defaults for reset) | ✅ (target sync) | — | — |
| **spoke-expand** | ✅ | ✅ (framework-aware scaffolding) | — | — | — |
| **spoke-ci** | ✅ | ✅ (language detection) | — | — | — |
| **spoke-migrate** | ✅ | ✅ | ✅ (run history) | ✅ (run reports for validation) | — |
| **spoke-coverage** | ✅ | — | ✅ (coverage trends) | ✅ (run + scan reports, raw coverage) | — |

---

## Lifecycle Notes

### Creation Order

1. **`spoke-init`** is the only spoke that creates `.bestest/` and its base structure. All other spokes require `.bestest/` to exist before operating.
2. The pre-flight protocol (see `references/pre-flight-protocol.md`) enforces this: every spoke checks for `.bestest/config.yaml` before proceeding.
3. If `.bestest/` already exists, `spoke-init` exits and suggests `/bestest doctor` instead.

### State Corruption Handling

All spokes that read `.bestest/state/*.json` apply pre-read validation:
1. Attempt to parse the JSON file.
2. If parsing succeeds: continue.
3. If parsing fails (SyntaxError, unexpected token): report corruption and offer options (regenerate, manual fix, abort).

See `references/pre-flight-protocol.md` for the shared validation pattern.

### Report Rotation

Only `spoke-scan` implements automatic report rotation:
- Controlled by `config.yaml` `state.max_retained` (default: 5).
- Only rotates `scan-*.json` files — never touches other report types.
- The newest report is never deleted.

### Safe Deletion

To start completely fresh:
```bash
rm -rf .bestest/
rm TESTING.md
# Also remove vitest.config.ts / jest.config.ts if no longer needed
```

Then re-run `/bestest init`. This is the only supported "reset" path. Individual files inside `.bestest/` should generally not be deleted in isolation — most are interdependent.
