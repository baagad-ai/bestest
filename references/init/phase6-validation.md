Part of **/bestest init** (see references/spoke-init.md). Load on-demand when reaching Phase 6.

## Phase 6 — Validation

### State File Corruption Handling

Before reading any `.bestest/state/*.json` file during validation, apply this pre-read validation:

```
1. Attempt to parse the JSON file.
2. If parsing succeeds: continue with validation.
3. If parsing fails (SyntaxError, unexpected token, etc.):
   Print: "⚠ State file corruption detected: {filename}"
   Print: "  The file contains invalid JSON and cannot be read."
   Print: "  Options:"
   Print: "    (a) Regenerate — re-run /bestest init to recreate from scratch."
   Print: "    (b) Manual fix — edit {filename} to correct the JSON syntax."
   Print: "    (c) Abort — exit without making changes."
   Wait for user choice. Do NOT proceed with corrupted state.
```

Verify that all expected files were created correctly and are syntactically valid.

### File Existence Check

Verify every expected file exists:

**JS/TS projects:**
```
.bestest/config.yaml          — exists and is valid YAML
.bestest/.gitignore           — exists
.bestest/.config.lock         — exists (empty lock file for config.yaml concurrency control)
.bestest/adrs/ADR-001-test-framework.md — exists and contains Status, Context, Decision, Rationale sections
.bestest/state/stack-profile.json — exists and is valid JSON matching references/stack-profile-schema.md
.bestest/state/.metrics.lock  — exists (empty lock file for metrics.json concurrency control)
.bestest/reports/             — directory exists (empty)
TESTING.md                    — exists at repo root (NOT inside .bestest/)
vitest.config.ts OR jest.config.ts — exists at repo root
```

**Python projects:**
```
.bestest/config.yaml          — exists and is valid YAML with framework: pytest
.bestest/.gitignore           — exists
.bestest/.config.lock         — exists (empty lock file for config.yaml concurrency control)
.bestest/adrs/ADR-001-test-framework.md — exists and contains Status, Context, Decision, Rationale sections
.bestest/state/stack-profile.json — exists and is valid JSON matching references/stack-profile-schema.md
.bestest/state/.metrics.lock  — exists (empty lock file for metrics.json concurrency control)
.bestest/reports/             — directory exists (empty)
TESTING.md                    — exists at repo root (NOT inside .bestest/)
pyproject.toml                — exists with [tool.pytest.ini_options] section (or pytest.ini)
tests/                        — directory exists with conftest.py
```

**Java projects:**
```
.bestest/config.yaml          — exists and is valid YAML with framework: junit5
.bestest/.gitignore           — exists
.bestest/.config.lock         — exists (empty lock file for config.yaml concurrency control)
.bestest/adrs/ADR-001-test-framework.md — exists and contains Status, Context, Decision, Rationale sections
.bestest/state/stack-profile.json — exists and is valid JSON matching references/stack-profile-schema.md
.bestest/state/.metrics.lock  — exists (empty lock file for metrics.json concurrency control)
.bestest/reports/             — directory exists (empty)
TESTING.md                    — exists at repo root (NOT inside .bestest/)
build.gradle or pom.xml       — exists with JUnit 5 dependencies added
src/test/java/                — test source directory exists
```

**Go projects:**
```
.bestest/config.yaml          — exists and is valid YAML with framework: go_testing
.bestest/.gitignore           — exists
.bestest/.config.lock         — exists (empty lock file for config.yaml concurrency control)
.bestest/adrs/ADR-001-test-framework.md — exists and contains Status, Context, Decision, Rationale sections
.bestest/state/stack-profile.json — exists and is valid JSON matching references/stack-profile-schema.md
.bestest/state/.metrics.lock  — exists (empty lock file for metrics.json concurrency control)
.bestest/reports/             — directory exists (empty)
TESTING.md                    — exists at repo root (NOT inside .bestest/)
go.mod                        — exists with testify dependency added
*_test.go files               — at least one test file exists
```

### Config Validation

Read `.bestest/config.yaml` and verify:
- `framework` field is present and is one of: `vitest`, `jest`, `pytest`, `junit5`, `go_testing`
- `language` field is present for Python projects (value: `python`), Java projects (value: `java`), and Go projects (value: `go`)
- `coverage.target` is a number between 0 and 100
- `paths.test` and `paths.src` are non-empty strings
- The framework-specific block (`vitest.*`, `jest.*`, or `pytest.*`) has non-empty values

### Summary Output

Print a completion summary:

```
