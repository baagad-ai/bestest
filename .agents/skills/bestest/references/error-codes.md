# Validation Error Codes

Error code taxonomy for `scripts/validate-skill.sh`. Each code represents one discrete consistency check that the validation script performs against the bestest skill's reference files, routing table, and structural integrity.

## Severity Definitions

| Severity | Meaning | CI Behavior |
|----------|---------|-------------|
| **critical** | Structural breakage — missing files, broken cross-references, or incomplete schema coverage that will cause runtime failures. | **Blocks CI** (exit 1) |
| **warning** | Degraded quality — empty sections, low content, or informational gaps that reduce plugin effectiveness but do not cause failures. | **Informational** (logged, exit 0) |

## Quick Reference Table

| Code | Severity | Domain | Summary |
|------|----------|--------|---------|
| E001 | critical | Structural Integrity | Routing table entry references a spoke file that does not exist on disk |
| E002 | critical | Structural Integrity | Spoke file exists on disk but is absent from the routing table |
| E003 | critical | Structural Integrity | Routing table entry references a spoke not listed in reference_index |
| E004 | critical | Structural Integrity | reference_index lists a spoke not present in the routing table |
| E005 | critical | Structural Integrity | reference_index entry references a file that does not exist on disk |
| E006 | warning | Structural Integrity | Spoke file listed in routing table is empty or near-empty (< 100 bytes) |
| E007 | critical | Schema Coverage | config-schema.md is missing required top-level fields |
| E008 | critical | Schema Coverage | scan-report-schema.md is missing required top-level fields |
| E009 | critical | Schema Coverage | stack-profile-schema.md referenced but not present on disk |
| E010 | warning | Schema Coverage | config-schema.md is missing per-framework variation blocks |
| E011 | warning | Schema Coverage | scan-report-schema.md is missing coverage metric sub-objects |
| E012 | warning | Schema Coverage | schema-contract.md version table is outdated or incomplete |
| E013 | critical | Detection Engine | detection-engine.md is missing one or more detection phases (1–7) |
| E014 | critical | Detection Engine | detection-engine.md confidence scoring section is absent or incomplete |
| E015 | warning | Detection Engine | detection-signals.md referenced from detection-engine.md does not exist |
| E016 | warning | Detection Engine | Phase 8 (Java/JVM) or Phase 9 (Go) conditional sections are missing |
| E017 | warning | Detection Engine | Early termination or monorepo detection sections are absent |
| E018 | critical | Template Completeness | Template file referenced in reference_index does not exist on disk |
| E019 | critical | Template Completeness | Template file exists but is empty or contains only a header |
| E020 | warning | Template Completeness | Template file is missing code block examples |
| E021 | warning | Template Completeness | TESTING.md template is missing required documentation sections |
| E022 | warning | Template Completeness | Template file has fewer than 20 lines of substantive content |
| E023 | critical | SKILL.md Integrity | SKILL.md YAML frontmatter is missing or malformed |
| E024 | critical | SKILL.md Integrity | SKILL.md is missing one or more required top-level sections |
| E025 | warning | SKILL.md Integrity | SKILL.md total line count is below the expected minimum |

---

## Structural Integrity

> Domain 1: E001–E006

These codes verify bidirectional consistency between the routing table, the reference_index, spoke file existence on disk, and file non-emptiness.

### E001 — Routing table spoke file does not exist

- **Severity:** critical
- **Check:** For every row in SKILL.md's `<routing>` table, the `Spoke File` column value (e.g., `references/spoke-init.md`) must resolve to an existing file relative to `~/.agents/skills/bestest/`.
- **Validates:** `SKILL.md` → `<routing>` → file system
- **Remediation:** Create the missing spoke file, or remove/fix the routing table entry. The spoke must exist before the command can execute.

### E002 — Orphan spoke file not in routing table

- **Severity:** critical
- **Check:** Every file matching `references/spoke-*.md` on disk must appear in the `<routing>` table's `Spoke File` column. Files listed in the `reference_index` under "Spokes" but not routed are acceptable only if they are sub-spokes (e.g., language-specific generate spokes routed via the generate command's language-aware routing).
- **Validates:** File system (`references/spoke-*.md`) → `SKILL.md` `<routing>`
- **Remediation:** Add a routing table entry for the orphan spoke, or remove the file if it is deprecated.

### E003 — Routing table entry not in reference_index

- **Severity:** critical
- **Check:** Every spoke file listed in the routing table must also appear in the `reference_index` section under the "Spokes" category.
- **Validates:** `SKILL.md` `<routing>` → `SKILL.md` `<reference_index>`
- **Remediation:** Add the missing entry to the reference_index, or remove the routing table row if the command is deprecated.

### E004 — reference_index spoke not in routing table

- **Severity:** critical
- **Check:** Every file listed in the reference_index "Spokes" category must appear in (or be reachable from) the routing table. Language-specific generate spokes (`spoke-generate-python.md`, `spoke-generate-java.md`, `spoke-generate-go.md`) are exempt — they are reached via the generate command's language-aware routing, not direct routing entries.
- **Validates:** `SKILL.md` `<reference_index>` → `SKILL.md` `<routing>`
- **Remediation:** Add a routing table entry for the spoke, or remove it from the reference_index.

### E005 — reference_index entry file does not exist

- **Severity:** critical
- **Check:** Every file path listed in any category of the reference_index must resolve to an existing file on disk relative to `~/.agents/skills/bestest/`.
- **Validates:** `SKILL.md` `<reference_index>` → file system
- **Remediation:** Create the missing reference file, or remove the stale reference_index entry.

### E006 — Spoke file is empty or near-empty

- **Severity:** warning
- **Check:** Every spoke file referenced in the routing table must contain at least 100 bytes of content. Near-empty files suggest incomplete authoring or accidental truncation.
- **Validates:** File content of each `references/spoke-*.md`
- **Remediation:** Populate the spoke file with its command specification, or remove the routing entry if the command is not yet implemented.

---

## Schema Coverage

> Domain 2: E007–E012

These codes verify that schema reference files contain all required fields and sections as defined by their contracts.

### E007 — config-schema.md missing required fields

- **Severity:** critical
- **Check:** `references/config-schema.md` must document all required top-level config fields: `framework`, `version`, `coverage`, `paths`, `e2e`, `api`, `mutation`, `contract`, `chaos`, `performance`, `ci`, `monorepo`, `generation`, `reports`, `state`. Each field must have a type, default, and description in its table entry.
- **Validates:** `references/config-schema.md` field inventory completeness
- **Remediation:** Add the missing field documentation to config-schema.md. Cross-reference the config YAML examples at the bottom of the file for the authoritative field list.

### E008 — scan-report-schema.md missing required fields

- **Severity:** critical
- **Check:** `references/scan-report-schema.md` must document all required top-level fields: `schemaVersion`, `timestamp`, `configSnapshot`, `summary`, `coverage`, `antiPatterns`, `flakyTests`, `gaps`, `testInventory`. Sub-objects (`summary.testTypes`, `coverage.*`, etc.) must also be present.
- **Validates:** `references/scan-report-schema.md` field inventory completeness
- **Remediation:** Add the missing field documentation to scan-report-schema.md. Each required field must have type and description.

### E009 — stack-profile-schema.md not found

- **Severity:** critical
- **Check:** `references/stack-profile-schema.md` must exist on disk. It is the schema definition for the StackProfile JSON that the detection engine produces and all downstream spokes consume.
- **Validates:** File existence of `references/stack-profile-schema.md`
- **Remediation:** Create the file or restore it from version control. The detection engine and all generate spokes depend on it.

### E010 — config-schema missing per-framework variation blocks

- **Severity:** warning
- **Check:** `references/config-schema.md` must contain per-framework documentation blocks for all 5 supported frameworks: `vitest`, `jest`, `pytest`, `junit5`, `go_testing`. Each block should document framework-specific fields with types, defaults, and valid values.
- **Validates:** `references/config-schema.md` per-framework section coverage
- **Remediation:** Add the missing framework variation block. Reference the example configs at the bottom of config-schema.md for the correct field structure.

### E011 — scan-report-schema missing coverage metric sub-objects

- **Severity:** warning
- **Check:** `references/scan-report-schema.md` must document the `coverage` sub-objects with all four metric types: `lines`, `branches`, `functions`, `statements`. Each must specify `total` (integer), `covered` (integer), and `pct` (number 0.0–100.0).
- **Validates:** `references/scan-report-schema.md` coverage section completeness
- **Remediation:** Add the missing coverage metric sub-object documentation.

### E012 — schema-contract version table outdated

- **Severity:** warning
- **Check:** `references/schema-contract.md` must list current versions for all versioned artifacts in its version table: `stack-profile.json`, `scan-report.json`, `run-results.json`, and `config.yaml`. Each entry must have version, date, and change description.
- **Validates:** `references/schema-contract.md` version history completeness
- **Remediation:** Update the version table entries. Cross-reference the actual schema files for their current `schemaVersion` or `version` field values.

---

## Detection Engine Structure

> Domain 3: E013–E017

These codes verify the detection engine specification is complete and internally consistent.

### E013 — detection-engine.md missing detection phases

- **Severity:** critical
- **Check:** `references/detection-engine.md` must contain sections for all 9 detection phases: Phase 1 (Language/Ecosystem), Phase 2 (Package Manager), Phase 3 (Build Tool), Phase 4 (Framework), Phase 5 (Test Framework), Phase 6 (E2E Framework), Phase 7 (CI/Monorepo/DB/Coverage), Phase 8 (Java/JVM conditional), Phase 9 (Go conditional).
- **Validates:** `references/detection-engine.md` phase completeness
- **Remediation:** Add the missing phase section(s) to detection-engine.md. Each phase should describe what it checks, what signals it looks for, and what confidence weight each signal carries.

### E014 — detection-engine.md missing confidence scoring section

- **Severity:** critical
- **Check:** `references/detection-engine.md` must contain a "Confidence Scoring Algorithm" section that documents the noisy-OR formula, signal strength weights (high=0.40, medium=0.20, low=0.08), the 0.99 cap, and the definitive single-signal override rule.
- **Validates:** `references/detection-engine.md` confidence scoring specification
- **Remediation:** Add or complete the confidence scoring section. The formula and weight table are non-negotiable for deterministic detection behavior.

### E015 — detection-signals.md cross-reference broken

- **Severity:** warning
- **Check:** `references/detection-engine.md` references `references/detection-signals.md` in its Signal Catalog section. That file must exist on disk and contain at least the signal categories referenced by the detection phases.
- **Validates:** `references/detection-engine.md` → `references/detection-signals.md` cross-reference
- **Remediation:** Create or restore detection-signals.md. The file should contain the complete catalog of detection signals with strength ratings.

### E016 — Conditional detection phases (Java/Go) missing

- **Severity:** warning
- **Check:** `references/detection-engine.md` must contain Phase 8 (Java/JVM Detection) and Phase 9 (Go Detection) conditional sections. These are triggered by Phase 1 detections and must document build tool detection, version detection, framework detection, and test framework detection for their respective ecosystems.
- **Validates:** `references/detection-engine.md` Phase 8 and Phase 9 presence
- **Remediation:** Add the missing conditional phase section(s). Reference the Java and Go config-schema blocks for the fields each phase must detect.

### E017 — Early termination or monorepo detection missing

- **Severity:** warning
- **Check:** `references/detection-engine.md` must contain an "Early Termination" section (describing the ≥0.90 confidence threshold optimization) and a "Monorepo Detection" section (listing workspace config files: pnpm-workspace.yaml, nx.json, turbo.json, lerna.json, WORKSPACE/BUILD.bazel, settings.gradle multi-include).
- **Validates:** `references/detection-engine.md` optimization and monorepo sections
- **Remediation:** Add the missing section(s). Early termination prevents wasted signal checks. Monorepo detection ensures correct workspace-aware routing.

---

## Template Completeness

> Domain 4: E018–E022

These codes verify that all template reference files exist, are non-empty, and contain meaningful content.

### E018 — Template file not found

- **Severity:** critical
- **Check:** Every file listed in the reference_index "Templates" category must exist on disk relative to `~/.agents/skills/bestest/`. Currently: `references/templates/vitest-config-ts.md`, `references/templates/jest-config-ts.md`, `references/templates/playwright-config-ts.md`, `references/templates/stryker-conf.md`, `references/templates/supertest-helpers.md`, `references/templates/testing-md.md`.
- **Validates:** `SKILL.md` `<reference_index>` "Templates" → file system
- **Remediation:** Create the missing template file, or remove it from the reference_index if no longer needed.

### E019 — Template file is empty

- **Severity:** critical
- **Check:** Every template file must contain more than just a header (title line). An empty template (only an `# H1` line with no body) fails this check.
- **Validates:** Content of each `references/templates/*.md`
- **Remediation:** Populate the template with configuration examples, usage notes, and at least one code block.

### E020 — Template missing code block examples

- **Severity:** warning
- **Check:** Every template file must contain at least one fenced code block (``` ``` or ```) with a concrete configuration example. Templates without code blocks are reference stubs, not usable templates.
- **Validates:** Presence of fenced code blocks in each `references/templates/*.md`
- **Remediation:** Add at least one complete configuration example as a fenced code block.

### E021 — TESTING.md template missing required sections

- **Severity:** warning
- **Check:** `references/templates/testing-md.md` must document or scaffold the following sections: Test Strategy, Framework Configuration, Coverage Baseline, Running Tests, CI Integration, Known Gaps. These are the minimum sections that `bestest init` generates.
- **Validates:** `references/templates/testing-md.md` section coverage
- **Remediation:** Add the missing sections to the TESTING.md template.

### E022 — Template file has insufficient content

- **Severity:** warning
- **Check:** Every template file must contain at least 20 lines of substantive content (excluding blank lines and lines containing only markdown headers). Short templates are unlikely to provide useful scaffolding.
- **Validates:** Line count of each `references/templates/*.md`
- **Remediation:** Expand the template with additional examples, configuration variants, or usage guidance.

---

## SKILL.md Integrity

> Domain 5: E023–E025

These codes verify that the main SKILL.md file has valid frontmatter and all required structural sections.

### E023 — SKILL.md frontmatter missing or malformed

- **Severity:** critical
- **Check:** `SKILL.md` must begin with valid YAML frontmatter delimited by `---` markers. Required frontmatter fields: `name` (string, must be `"bestest"`), `version` (semver string), `description` (non-empty string), `triggers` (non-empty array of trigger strings).
- **Validates:** `SKILL.md` YAML frontmatter structure
- **Remediation:** Fix or add the frontmatter block. The `name` field must match `"bestest"`. The `version` field must follow semver (e.g., `"1.2.0"`). The `triggers` array must include `"/bestest"` and `"bestest"`.

### E024 — SKILL.md missing required sections

- **Severity:** critical
- **Check:** `SKILL.md` must contain all required top-level XML-style or markdown sections: `<essential_principles>` (or `## Essential Principles`), `<detection_engine>` (or detection engine reference), `<routing>` (routing table), `<reference_index>` (reference file listing), `<success_criteria>` (or success criteria section).
- **Validates:** `SKILL.md` section structure
- **Remediation:** Add the missing section(s). Each section serves a distinct purpose: principles govern behavior, detection drives profiling, routing dispatches commands, reference_index tracks all files, and success_criteria defines correctness.

### E025 — SKILL.md below minimum line count

- **Severity:** warning
- **Check:** `SKILL.md` must contain at least 200 lines total. A significantly shorter file likely indicates content loss from an accidental truncation or incomplete authoring.
- **Validates:** `SKILL.md` total line count
- **Remediation:** Investigate whether content was lost. Compare against version control history. A full SKILL.md with all sections, routing table, and reference_index typically exceeds 300 lines.

---

## Usage in Validation Script

The validation script (`scripts/validate-plugin.sh`) should:

1. **Load this file** and parse the error code table for the check catalog.
2. **Run checks sequentially** by domain (structural → schema → detection → template → SKILL.md).
3. **Report each finding** using the error code, e.g.: `E001: references/spoke-foo.md referenced in routing table but not found on disk`.
4. **Exit with code 0** if only warnings (E006, E010–E012, E015–E022, E025) are found.
5. **Exit with code 1** if any critical errors (E001–E005, E007–E009, E013–E014, E018–E019, E023–E024) are found.
6. **Output a summary** with counts: `X critical, Y warnings, Z total checks passed`.

## Cross-Reference

- Routing table: `SKILL.md` `<routing>` section
- Reference index: `SKILL.md` `<reference_index>` section
- Config schema: `references/config-schema.md`
- Scan report schema: `references/scan-report-schema.md`
- Stack profile schema: `references/stack-profile-schema.md`
- Schema contract: `references/schema-contract.md`
- Detection engine: `references/detection-engine.md`
- Detection signals: `references/detection-signals.md`
- Templates directory: `references/templates/`

