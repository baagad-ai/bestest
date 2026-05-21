Part of **/bestest init** (see references/spoke-init.md). Load on-demand when reaching Output and Metrics Update.

## Output

After successful completion, the following files exist:

**JS/TS projects:**

| File | Location | Purpose |
|------|----------|---------|
| `config.yaml` | `.bestest/` | Test framework, coverage, paths, and generation settings |
| `.gitignore` | `.bestest/` | Ignore state/, reports/, cache/, and lock files |
| `.config.lock` | `.bestest/` | Advisory lock file for config.yaml concurrency control |
| `stack-profile.json` | `.bestest/state/` | Detected technology stack with confidence scores |
| `.metrics.lock` | `.bestest/state/` | Advisory lock file for metrics.json concurrency control |
| `ADR-001-test-framework.md` | `.bestest/adrs/` | Framework selection decision record |
| — (empty directory) | `.bestest/reports/` | Future home for scan and coverage reports |
| `TESTING.md` | **Repo root** | Living test documentation |
| `vitest.config.ts` or `jest.config.ts` | **Repo root** | Framework-specific configuration |

**Python projects:**

| File | Location | Purpose |
|------|----------|---------|
| `config.yaml` | `.bestest/` | Test framework (pytest), coverage, paths, and generation settings |
| `.gitignore` | `.bestest/` | Ignore state/, reports/, cache/, and lock files |
| `.config.lock` | `.bestest/` | Advisory lock file for config.yaml concurrency control |
| `stack-profile.json` | `.bestest/state/` | Detected technology stack with confidence scores |
| `.metrics.lock` | `.bestest/state/` | Advisory lock file for metrics.json concurrency control |
| `ADR-001-test-framework.md` | `.bestest/adrs/` | Framework selection decision record |
| — (empty directory) | `.bestest/reports/` | Future home for scan and coverage reports |
| `TESTING.md` | **Repo root** | Living test documentation |
| `[tool.pytest.ini_options]` section | `pyproject.toml` | pytest configuration (or `pytest.ini`) |
| `conftest.py` | `tests/` | Root test fixtures |
| `tests/` directory | **Repo root** | Test directory with unit/ and integration/ subdirs |

**Java projects:**

| File | Location | Purpose |
|------|----------|---------|
| `config.yaml` | `.bestest/` | Test framework (junit5), coverage (JaCoCo), paths, and generation settings |
| `.gitignore` | `.bestest/` | Ignore state/, reports/, cache/, and lock files |
| `.config.lock` | `.bestest/` | Advisory lock file for config.yaml concurrency control |
| `stack-profile.json` | `.bestest/state/` | Detected technology stack with confidence scores |
| `.metrics.lock` | `.bestest/state/` | Advisory lock file for metrics.json concurrency control |
| `ADR-001-test-framework.md` | `.bestest/adrs/` | Framework selection decision record |
| — (empty directory) | `.bestest/reports/` | Future home for scan and coverage reports |
| `TESTING.md` | **Repo root** | Living test documentation |
| JUnit 5 dependencies | `build.gradle` or `pom.xml` | JUnit 5, Mockito, AssertJ, JaCoCo, and Spring Boot test starters (if applicable) |
| `src/test/java/` | **Repo root** | Test source directory following Maven/Gradle conventions |

**Go projects:**

| File | Location | Purpose |
|------|----------|---------|
| `config.yaml` | `.bestest/` | Test framework (go_testing), coverage (go test -cover), paths, and generation settings |
| `.gitignore` | `.bestest/` | Ignore state/, reports/, cache/, and lock files |
| `.config.lock` | `.bestest/` | Advisory lock file for config.yaml concurrency control |
| `stack-profile.json` | `.bestest/state/` | Detected technology stack with confidence scores |
| `.metrics.lock` | `.bestest/state/` | Advisory lock file for metrics.json concurrency control |
| `ADR-001-test-framework.md` | `.bestest/adrs/` | Framework selection decision record |
| — (empty directory) | `.bestest/reports/` | Future home for scan and coverage reports |
| `TESTING.md` | **Repo root** | Living test documentation |
| testify dependency | `go.mod` / `go.sum` | testify assertion library (assert/require/mock/suite) |
| `*_test.go` files | **Alongside source** | Test files following Go's `*_test.go` convention |

No files are created inside `.bestest/` until Phase 4 (after the HITL gate in Phase 3). The user can cancel at any point before Phase 4 with no artifacts left behind.

---

## Metrics Update

This spoke writes to `.bestest/state/metrics.json` following the shared metrics-update protocol defined in `references/metrics-schema.md`.

### Sections Updated

Creates `metrics.json` with defaults. No section merges.

### Field Mapping

| Field | Source | Update Rule |
|-------|--------|-------------|
| *(all fields)* | Default values from schema | Written from scratch |

### Update Protocol

Follow this 7-step protocol on every invocation:

```
1. Read .bestest/state/metrics.json
2. Parse as JSON
3. If parse fails (corruption):
   a. Log warning: "metrics.json corrupted — recreating with defaults"
   b. Initialize fresh metrics with schemaVersion "1.0" and default values
   c. Continue with step 5 (do NOT abort the spoke)
4. Validate schemaVersion — warn if MAJOR differs, proceed if MINOR differs
5. Merge spoke-specific data:
   - Update lastUpdated to current ISO 8601 timestamp
   - Update only this spoke's sections (listed above), leave others unchanged
   - Append to bounded arrays (history, trend, activity), evicting oldest when over maxLength
   - Recalculate derived values (healthScore, overallFlakeRate, etc.)
6. Write back to .bestest/state/metrics.json (atomic write: write to temp file, then rename)
7. Update config.yaml state.last_metrics with current timestamp
```

### Activity Log Entry

Append an entry to the `activity` array:

```json
{
  "timestamp": "<current ISO 8601>",
  "spoke": "spoke-init",
  "action": "init",
  "summary": "<human-readable one-line summary>"
}
```

### Graceful Degradation

- **File missing:** Treated as first-time creation. Write this spoke's section with defaults for all others.
- **Parse failure:** Log warning, recreate with defaults + current spoke's data. **Never abort the spoke** — metrics are observability, not a gate.
- **schemaVersion mismatch (MAJOR):** Log warning, attempt to read known fields, write back with current schema version.
- **schemaVersion mismatch (MINOR):** Proceed normally. Unrecognized fields are preserved (pass-through).

### Special: Initial Creation

This spoke creates `metrics.json` with all default values (see metrics-schema.md Default Values section). No section merges occur — the file is written from scratch. After creation, other spokes will merge their data into it.

## Downstream

After `init` completes, the user can:
- Run `/bestest scan` — audit current test coverage and identify untested source files
- Run `/bestest generate --untested` — AI-generate tests for uncovered source files
- Run `/bestest config show` — view current configuration
- Run `/bestest doctor` — validate that the setup is healthy
- Run `/bestest ci` — generate a CI pipeline configuration
