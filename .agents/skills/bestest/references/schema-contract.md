# Schema Contract

This document defines the canonical versioning policy for all bestest schema artifacts. Every structured JSON document that bestest reads or writes carries a `schemaVersion` field. Consuming spokes must validate this field before parsing to detect breaking changes.

## Version Policy

### Version Format

Schema versions use semver-minor notation: `"MAJOR.MINOR"` (e.g., `"1.3"`).

- **MAJOR**: Incremented when fields are removed, renamed, or change type in a backward-incompatible way.
- **MINOR**: Incremented when fields are added or semantics are refined in a backward-compatible way.

Patches (documentation-only changes) do not increment the version.

### Where schemaVersion Lives

| Artifact | schemaVersion Field | Current Version |
|----------|--------------------|-----------------|
| `stack-profile.json` | Top-level `schemaVersion` | `1.3` |
| `scan-report.json` | Top-level `schemaVersion` | `1.2` |
| `run-results.json` | Top-level `schemaVersion` | `1.0` |
| `metrics.json` | Top-level `schemaVersion` | `1.0` |
| `config.yaml` | `version` (top-level) | `1.0` |

### Version History

#### stack-profile-schema

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2024-07 | Initial schema |
| 1.1 | 2024-08 | Added `schemaVersion` field |
| 1.2 | 2024-09 | Added `selectedLanguage`, `e2eFramework`, `ciProvider`, `monorepo`, `packageManager`, `frontend`, `databases`, `messageQueues` |
| 1.3 | 2025-04 | Normalized `testFrameworks.existing` to `string[] | null` (was `string | string[] | null`). Fixed `coverage.provider` valid-values to use canonical names across all 5 languages. Aliases: `coverage.py` maps to `pytest-cov`, `go-cover` maps to `go_cover` — consumers should normalize before comparison. |

#### scan-report-schema

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2024-07 | Initial schema |
| 1.1 | 2024-08 | Added `schemaVersion` field |
| 1.2 | 2025-04 | Expanded `configSnapshot` to cover all config sections (api, mutation, contract, chaos, performance, reports, state). Expanded `framework` valid-values to all 5 languages. |

#### run-results-schema

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2025-04 | Initial versioned schema. Added `schemaVersion` field to run-results.json shape. |

#### run-results-schema

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2025-04 | Initial versioned schema. Added `schemaVersion` field to run-results.json shape. |

#### metrics-schema

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2025-04 | Initial schema. Metrics store for continuous test health aggregation across all spokes. |

#### config-schema

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2024-07 | Initial schema |
| 1.1 | 2025-04 | Expanded `coverage.provider` and `coverage.reporters` valid-values to cover all 5 languages (Python, Java, Go added). |

## Consuming Spoke Validation

Every spoke that reads a structured artifact must validate `schemaVersion` before consuming the data:

### Validation Algorithm

```
1. Read the artifact file.
2. Parse as JSON (or YAML for config).
3. Check for the presence of the schemaVersion field.
4. If the field is missing:
   - For stack-profile and scan-report: treat as version "1.0" (pre-versioning legacy).
   - For run-results: treat as an error — all run-results.json files must have schemaVersion.
5. If the field is present:
   - Compare against the spoke's known-compatible version range.
   - If MAJOR version matches and MINOR version ≤ spoke's known version: proceed normally.
   - If MAJOR version matches but MINOR version > spoke's known version: proceed with a warning about unrecognized fields (additive change).
   - If MAJOR version differs: emit an error. The spoke cannot safely parse this artifact. Suggest the user update bestest.
```

### Validation in Each Spoke

| Spoke | What It Validates | On Mismatch |
|-------|-------------------|-------------|
| `spoke-scan` | `stack-profile.json` schemaVersion | Warn if > known version. Error if MAJOR differs. |
| `spoke-run` | `config.yaml` version + `stack-profile.json` schemaVersion | Warn if config version > known. Error if stack-profile MAJOR differs. |
| `spoke-generate` | `stack-profile.json` schemaVersion + `scan-report.json` schemaVersion | Warn on unknown minor. Error on MAJOR mismatch. |
| `spoke-fix` | `run-results.json` schemaVersion | Error if missing or MAJOR differs. |
| `spoke-coverage` | `run-results.json` schemaVersion + `config.yaml` version | Warn on unknown minor. Error on MAJOR mismatch. |
| `spoke-doctor` | `config.yaml` version + `stack-profile.json` schemaVersion | Warn on unknown minor. Error on MAJOR mismatch. |
| `spoke-config` | `config.yaml` version | Warn if > known version. Do not overwrite newer versions. |
| `spoke-report` | `metrics.json` schemaVersion | Warn on unknown minor. Error on MAJOR mismatch. |
| `spoke-doctor` | `metrics.json` schemaVersion + `config.yaml` version + `stack-profile.json` schemaVersion | Warn on unknown minor. Error on MAJOR mismatch. |
| `spoke-coverage` | `metrics.json` schemaVersion + `run-results.json` schemaVersion + `config.yaml` version | Warn on unknown minor. Error on MAJOR mismatch. |

## Breaking vs Non-Breaking Changes

### Breaking (increment MAJOR)

- Removing a field from the JSON shape
- Renaming a field
- Changing a field's type (e.g., `string` → `string[]`)
- Changing a field from required to optional (or vice versa) in a way that changes the parsing contract
- Changing the semantics of an enum value

### Non-Breaking (increment MINOR)

- Adding a new optional field
- Adding a new enum value to an existing field
- Adding a new valid value to a string constraint
- Refining documentation or description text
- Adding a new top-level section to config.yaml

## Cross-Reference

- Schema shapes: `references/stack-profile-schema.md`, `references/scan-report-schema.md`, `references/config-schema.md`, `references/metrics-schema.md`
- Consuming spokes: `references/spoke-scan.md`, `references/spoke-run.md`, `references/spoke-generate.md`, `references/spoke-fix.md`, `references/spoke-coverage.md`, `references/spoke-doctor.md`, `references/spoke-config.md`
- Prompt injection defense: `references/context3-helper.md` (L4 schema validation)
