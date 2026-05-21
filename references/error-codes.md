# Validation Error Codes

Error code taxonomy for `scripts/validate-skill.sh` and `scripts/validate-plugin.sh`. Each code represents one discrete consistency check that the validation scripts perform against the bestest skill's routing table, reference index, spoke files, detection engine, schemas, templates, SKILL.md integrity, and dashboard/JUnit cross-references.

## Severity Definitions

| Severity | Meaning | CI Behavior |
|----------|---------|-------------|
| **critical** | Structural breakage — missing files, broken cross-references, missing sections, or incomplete schema coverage that will cause runtime failures. | **Blocks CI** (exit 1) |
| **warning** | Degraded quality — informational gaps such as line count outside recommended bounds that reduce effectiveness but do not cause failures. | **Informational** (logged, exit 0) |

## Quick Reference Table

| Code | Severity | Domain | Summary |
|------|----------|--------|---------|
| E001 | critical | Routing & Index Consistency | Routing table spoke not listed in reference_index |
| E002 | critical | Routing & Index Consistency | reference_index spoke not listed in routing table |
| E003 | critical | Reference Index & File Existence | reference_index entry does not exist on disk |
| E004 | critical | Reference Index & File Existence | Disk file not listed in reference_index |
| E004b | critical | Reference Index & File Existence | Generate spoke does not reference pipeline-shared.md (validate-skill.sh only) |
| E005 | critical | Spoke & Generate File Integrity | Spoke file from routing table does not exist or is empty |
| E006 | critical | Spoke & Generate File Integrity | Generate sub-file (4 languages × 6 files) does not exist or is empty |
| E007 | critical | Detection Engine Structure | detection-engine.md missing Phase 1–9 heading |
| E008 | critical | Detection Engine Structure | detection-engine.md missing Confidence Scoring Algorithm section |
| E009 | critical | Detection Engine Structure | detection-engine.md missing Output/Signal Catalog sections, or detection-signals.md / stack-profile-schema.md missing or incomplete |
| E010 | critical | Schema Field Coverage | config-schema.md missing a required field group |
| E011 | critical | Schema Field Coverage | scan-report-schema.md missing a required top-level field |
| E012 | critical | Schema Field Coverage | schema-contract.md missing Version Policy or version table entries |
| E012b | critical | Schema Field Coverage | metrics-schema.md does not exist or is empty (validate-skill.sh only) |
| E012c | critical | Schema Field Coverage | metrics-schema.md missing a required field (validate-skill.sh only) |
| E012d | critical | Schema Field Coverage | schema-contract.md missing metrics.json in version table (validate-skill.sh only) |
| E013 | critical | Template Completeness | Template file (YAML config, CI config, MD template, or gitignore) missing or empty |
| E014 | — | Reserved | Not implemented by any validation script. Reserved for future use. |
| E015 | critical | SKILL.md Integrity | SKILL.md frontmatter missing name or version field |
| E016 | critical | SKILL.md Integrity | SKILL.md missing a required XML wrapper section |
| E017 | warning | SKILL.md Integrity | SKILL.md line count outside bounds |
| E018 | critical | Dashboard & JUnit Cross-Cutting | dashboard.html template missing or empty (validate-plugin.sh only) |
| E019 | critical | Dashboard & JUnit Cross-Cutting | dashboard.html does not reference metrics.json (validate-plugin.sh only) |
| E020 | critical | Dashboard & JUnit Cross-Cutting | spoke-init.md does not reference dashboard.html (validate-plugin.sh only) |
| E021 | critical | Dashboard & JUnit Cross-Cutting | dot-bestest-schema.md does not reference dashboard.html or junit-report.xml (validate-plugin.sh only) |
| E022 | validate-skill.sh | critical | Generate spoke missing Write Companion Run Report in Phase 6. |
| E023 | validate-skill.sh | critical | Generate spoke missing Run report (companion) in Output table. |
| E024 | validate-skill.sh | critical | Generate spoke Phase 2 step numbering not monotonically increasing. |
| E025 | validate-skill.sh | warning | Generate spoke Metrics Update section does not reference pipeline-shared.md. |

---

## Domain 1: Routing & Index Consistency

> E001–E002

These codes verify bidirectional consistency between the SKILL.md routing table (`<routing>`) and the reference_index Spokes section. Every spoke in the routing table must appear in the reference_index and vice versa (with an exemption for language-specific generate spokes).

### E001 — Routing table spoke not listed in reference_index

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** For every row in SKILL.md's `<routing>` table, the `Spoke File` column value (e.g., `references/spoke-init.md`) must appear in the reference_index Spokes section.
- **Validates:** `SKILL.md` `<routing>` → `SKILL.md` `<reference_index>` (or external `reference-index.md`)
- **Remediation:** Add the missing entry to the reference_index Spokes section, or remove the routing table row if the command is deprecated.

### E002 — reference_index spoke not listed in routing table

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** Every spoke file listed in the reference_index Spokes section must appear in the routing table's `Spoke File` column. Language-specific generate spokes (`spoke-generate-python.md`, `spoke-generate-java.md`, `spoke-generate-go.md`) are exempt — they are reached via the generate command's language-aware routing, not direct routing entries.
- **Validates:** `SKILL.md` `<reference_index>` → `SKILL.md` `<routing>`
- **Remediation:** Add a routing table entry for the orphan spoke, or remove the reference_index entry if it is deprecated.

---

## Domain 2: Reference Index & File Existence

> E003–E004, E004b

These codes verify that every path listed in the reference_index resolves to an actual file on disk and that every reference file on disk is tracked in the reference_index. E004b additionally verifies that generate spokes correctly reference the shared pipeline file.

### E003 — reference_index entry does not exist on disk

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** Every file path listed in any category of the reference_index must resolve to an existing file on disk relative to `~/.agents/skills/bestest/`.
- **Validates:** `SKILL.md` `<reference_index>` → file system
- **Remediation:** Create the missing reference file, or remove the stale reference_index entry.

### E004 — Disk file not listed in reference_index

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** Every `.md` file in `references/` (excluding `templates/` subdirectory and `error-codes.md`) must appear in the reference_index. This catches orphan files that exist on disk but are not tracked.
- **Validates:** File system (`references/*.md`) → `SKILL.md` `<reference_index>`
- **Remediation:** Add the file to the reference_index, or remove the file from disk if it is deprecated.

### E004b — Generate spoke does not reference pipeline-shared.md

- **Severity:** critical
- **Scripts:** validate-skill.sh only
- **Check:** Each of the four generate spokes (`spoke-generate.md`, `spoke-generate-python.md`, `spoke-generate-java.md`, `spoke-generate-go.md`) must contain the string `pipeline-shared` to confirm they reference the shared pipeline logic.
- **Validates:** `references/spoke-generate*.md` → `pipeline-shared` reference
- **Remediation:** Add a `pipeline-shared` reference to the generate spoke. This ensures all language-specific spokes share a common generation pipeline.

---

## Domain 3: Spoke & Generate File Integrity

> E005–E006

These codes verify that spoke files from the routing table exist and are non-empty, and that all generate sub-files across the four language variants (JS/TS, Python, Java, Go) are present with content.

### E005 — Spoke file from routing table does not exist or is empty

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** Every spoke file referenced in the routing table must exist on disk and be non-empty (checked via `-s` file test). Missing or zero-length spoke files fail this check.
- **Validates:** `SKILL.md` `<routing>` → file system (existence and non-empty)
- **Remediation:** Create or populate the spoke file, or remove the routing table entry if the command is not yet implemented.

### E006 — Generate sub-file does not exist or is empty

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** All 24 generate sub-files must exist and be non-empty: 6 files (phase1-target-detail.md, phase4-generation-detail.md, phase5-compilation.md, phase6-execution.md, phase7-quality-audit.md, error-handling.md) across 4 language directories (JS/TS at `references/generate/`, and Python/Java/Go at `references/generate/<lang>/`).
- **Validates:** `references/generate/**/*.md` existence and non-emptiness
- **Remediation:** Create or populate the missing generate sub-file. Each file governs a specific generation phase and must contain the language-specific instructions for that phase.

---

## Domain 4: Detection Engine Structure

> E007–E009

These codes verify that the detection engine specification (`detection-engine.md`) is structurally complete, containing all required phase headings, the confidence scoring algorithm, output sections, and that cross-referenced files exist and are correct.

### E007 — detection-engine.md missing Phase heading

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** `references/detection-engine.md` must contain headings for all 9 detection phases: Phase 1 (Language/Ecosystem), Phase 2 (Package Manager), Phase 3 (Build Tool), Phase 4 (Framework), Phase 5 (Test Framework), Phase 6 (E2E Framework), Phase 7 (CI/Monorepo/DB/Coverage), Phase 8 (Java/JVM conditional), Phase 9 (Go conditional). The check greps for `Phase N` for each phase number 1–9.
- **Validates:** `references/detection-engine.md` phase heading completeness
- **Remediation:** Add the missing phase heading section(s) to detection-engine.md. Each phase should describe what it checks, what signals it looks for, and what confidence weight each signal carries.

### E008 — detection-engine.md missing Confidence Scoring Algorithm section

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** `references/detection-engine.md` must contain a section with the heading "Confidence Scoring Algorithm". This section documents the noisy-OR formula, signal strength weights, the 0.99 cap, and the definitive single-signal override rule.
- **Validates:** `references/detection-engine.md` confidence scoring specification
- **Remediation:** Add or complete the "Confidence Scoring Algorithm" section. The formula and weight table are non-negotiable for deterministic detection behavior.

### E009 — detection-engine.md missing Output/Signal Catalog sections, or related files missing/incomplete

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** This is a compound check covering multiple aspects of the detection engine's output specification:
  1. `detection-engine.md` must contain an "Output" section heading.
  2. `detection-engine.md` must contain a "Signal Catalog" section.
  3. `references/detection-signals.md` must exist and be non-empty.
  4. `references/stack-profile-schema.md` must exist on disk.
  5. `stack-profile-schema.md` must document the required fields: `schemaVersion`, `languages`, `buildTool`, `frameworks`, `testFrameworks`, `coverage`.
- **Validates:** `references/detection-engine.md` output structure → `references/detection-signals.md` → `references/stack-profile-schema.md` field completeness
- **Remediation:** Add the missing section to detection-engine.md, create or restore detection-signals.md, or add the missing field documentation to stack-profile-schema.md.

---

## Domain 5: Schema Field Coverage

> E010–E012, E012b–E012d

These codes verify that schema reference files document all required fields and that the schema-contract.md version table is current and complete.

### E010 — config-schema.md missing a required field group

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** `references/config-schema.md` must document each of 18 required field groups: `coverage`, `paths`, `e2e`, `api`, `mutation`, `contract`, `chaos`, `performance`, `ci`, `vitest`, `jest`, `pytest`, `junit5`, `go`, `monorepo`, `generation`, `reports`, `state`. The check greps for each group name followed by `.*` (regex pattern `${group}\.\*`).
- **Validates:** `references/config-schema.md` field inventory completeness
- **Remediation:** Add the missing field group documentation to config-schema.md. Cross-reference the config YAML examples for the authoritative field list.

### E011 — scan-report-schema.md missing a required top-level field

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** `references/scan-report-schema.md` must document each of 7 required top-level fields: `configSnapshot`, `summary`, `coverage`, `antiPatterns`, `flakyTests`, `gaps`, `testInventory`.
- **Validates:** `references/scan-report-schema.md` field inventory completeness
- **Remediation:** Add the missing field documentation to scan-report-schema.md.

### E012 — schema-contract.md missing Version Policy or version table entries

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** `references/schema-contract.md` must contain a "Version Policy" section and must reference all three core artifacts (`stack-profile`, `scan-report`, `run-results`) in its version table.
- **Validates:** `references/schema-contract.md` version policy and history completeness
- **Remediation:** Add the Version Policy section or update the version table to include all three artifacts.

### E012b — metrics-schema.md does not exist or is empty

- **Severity:** critical
- **Scripts:** validate-skill.sh only
- **Check:** `references/metrics-schema.md` must exist on disk and be non-empty (checked via `-s` file test). This is the schema definition for the metrics.json artifact consumed by the dashboard.
- **Validates:** File existence and non-emptiness of `references/metrics-schema.md`
- **Remediation:** Create or populate `references/metrics-schema.md`. The dashboard depends on this schema for metrics rendering.

### E012c — metrics-schema.md missing a required field

- **Severity:** critical
- **Scripts:** validate-skill.sh only
- **Check:** `references/metrics-schema.md` must document each of 6 required fields: `schemaVersion`, `healthScore`, `coverage`, `tests`, `runs`, `activity`.
- **Validates:** `references/metrics-schema.md` field inventory completeness
- **Remediation:** Add the missing field documentation to metrics-schema.md.

### E012d — schema-contract.md missing metrics.json in version table

- **Severity:** critical
- **Scripts:** validate-skill.sh only
- **Check:** `references/schema-contract.md` must reference `metrics.json` in its version table, ensuring the metrics artifact is tracked alongside the other versioned artifacts.
- **Validates:** `references/schema-contract.md` version table completeness
- **Remediation:** Add a `metrics.json` entry to the schema-contract.md version table.

---

## Domain 6: Template Completeness

> E013

This code verifies that all template reference files (YAML configs, CI configs, MD templates, and gitignore) exist and are non-empty.

### E013 — Template file missing or empty

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** The following template files must all exist and be non-empty:
  - **6 YAML config templates:** `config-vitest.yaml`, `config-jest.yaml`, `config-pytest.yaml`, `config-junit5.yaml`, `config-go.yaml`, `config-monorepo.yaml`
  - **3 CI templates:** `ci/github-actions-test.yml`, `ci/gitlab-ci-test.yml`, `ci/jenkinsfile-test.groovy`
  - **6 MD templates:** `vitest-config-ts.md`, `jest-config-ts.md`, `playwright-config-ts.md`, `stryker-conf.md`, `supertest-helpers.md`, `testing-md.md`
  - **1 gitignore:** `bestest-gitignore`

  All paths are relative to `references/templates/`.
- **Validates:** `references/templates/**` existence and non-emptiness
- **Remediation:** Create or populate the missing template file. Each template provides scaffolding output for the `bestest init` and `bestest generate` commands.

---

## Domain 7: SKILL.md Integrity

> E015–E017

These codes verify that the main SKILL.md file has valid YAML frontmatter with required fields, all required XML wrapper sections, and an appropriate line count.

### E015 — SKILL.md frontmatter missing name or version field

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** SKILL.md's first 10 lines must contain:
  1. `name: bestest` — the skill name must be exactly "bestest"
  2. `version:` — a version field must be present (semver string expected)
- **Validates:** `SKILL.md` YAML frontmatter structure
- **Remediation:** Fix or add the frontmatter block. The `name` field must be exactly `bestest`. The `version` field must follow semver (e.g., `1.2.0`).

### E016 — SKILL.md missing a required XML wrapper section

- **Severity:** critical
- **Scripts:** validate-skill.sh, validate-plugin.sh
- **Check:** SKILL.md must contain all 8 required XML wrapper section opening tags:
  1. `<essential_principles>`
  2. `<detection_engine>`
  3. `<framework_decision>`
  4. `<context7_helper>`
  5. `<routing>`
  6. `<quick_reference>`
  7. `<reference_index>`
  8. `<success_criteria>`
- **Validates:** `SKILL.md` XML section structure
- **Remediation:** Add the missing section(s). Each section serves a distinct purpose: principles govern behavior, detection drives profiling, routing dispatches commands, reference_index tracks all files, and success_criteria defines correctness.

### E017 — SKILL.md line count outside bounds

- **Severity:** warning
- **Scripts:** validate-skill.sh (bounds: 200–310), validate-plugin.sh (bounds: 180–325)
- **Check:** SKILL.md total line count must fall within the accepted bounds. validate-skill.sh enforces stricter bounds (200–310) optimized for the token budget of skill validation. validate-plugin.sh uses relaxed bounds (180–325) to accommodate structural variation in plugin contexts. A line count outside these ranges suggests content loss from truncation or bloat from duplicate content.
- **Validates:** `SKILL.md` total line count
- **Remediation:** Investigate whether content was lost or duplicated. Compare against version control history.

---

## Domain 8: Dashboard & JUnit Cross-Cutting

> E018–E021

These codes verify cross-references between the dashboard template, metrics data, spoke initialization, and schema documentation. These checks run only in validate-plugin.sh.

### E018 — dashboard.html template missing or empty

- **Severity:** critical
- **Scripts:** validate-plugin.sh only
- **Check:** `references/templates/dashboard.html` must exist and be non-empty (checked via `-s` file test).
- **Validates:** `references/templates/dashboard.html` existence and non-emptiness
- **Remediation:** Create or populate the dashboard template. The dashboard provides the visual metrics output for `bestest dashboard`.

### E019 — dashboard.html does not reference metrics.json

- **Severity:** critical
- **Scripts:** validate-plugin.sh only
- **Check:** `references/templates/dashboard.html` must contain the string `metrics.json`, confirming that the dashboard template reads from the metrics data source.
- **Validates:** `references/templates/dashboard.html` → metrics data binding
- **Remediation:** Add a `metrics.json` reference to the dashboard template (e.g., a fetch/XHR call or script src).

### E020 — spoke-init.md does not reference dashboard.html

- **Severity:** critical
- **Scripts:** validate-plugin.sh only
- **Check:** `references/spoke-init.md` must contain the string `dashboard.html`, confirming that the init spoke documents or deploys the dashboard template.
- **Validates:** `references/spoke-init.md` → dashboard template cross-reference
- **Remediation:** Add a `dashboard.html` reference to spoke-init.md to ensure the init command is aware of the dashboard artifact.

### E021 — dot-bestest-schema.md does not reference dashboard.html or junit-report.xml

- **Severity:** critical
- **Scripts:** validate-plugin.sh only
- **Check:** `references/dot-bestest-schema.md` must contain both `dashboard.html` and `junit-report.xml` references, confirming that the `.bestest/` directory schema tracks these output artifacts.
- **Validates:** `references/dot-bestest-schema.md` → output artifact tracking
- **Remediation:** Add the missing reference(s) to dot-bestest-schema.md. Both the dashboard HTML and JUnit XML report are core output artifacts that must be tracked in the directory schema.

---

## Reserved & Planned Codes

### E014 — Reserved

- **Status:** Reserved for future use. Not implemented by any validation script.
- **Note:** This code slot is available for a future check. Do not assign it without updating this document and implementing the corresponding check in at least one validation script.

### E022 — Generate spoke missing Write Companion Run Report in Phase 6

- **Severity:** critical
- **Scripts:** validate-skill.sh
- **Check:** For each of the 4 generate spoke files (spoke-generate.md, spoke-generate-python.md, spoke-generate-java.md, spoke-generate-go.md), the Phase 6 section must contain a `### Write Companion Run Report` heading between the Phase 6 and Phase 7 boundaries. This ensures all spokes produce companion run reports with structural parity.
- **Validates:** `references/spoke-generate*.md` → Phase 6 companion report subsection
- **Remediation:** Add the `### Write Companion Run Report` subsection to the spoke's Phase 6, between the on-demand load paragraph and the Phase 7 separator. Copy the canonical content from spoke-generate.md.

### E023 — Generate spoke missing Run report (companion) in Output table

- **Severity:** critical
- **Scripts:** validate-skill.sh
- **Check:** For each of the 4 generate spoke files, the Output artifact table must contain a `Run report (companion)` row. This ensures the companion report is documented as a first-class output artifact across all generate spokes.
- **Validates:** `references/spoke-generate*.md` → Output artifact table
- **Remediation:** Add a `Run report (companion)` row to the spoke's Output artifact table, immediately after the "Generated test files" row. Copy the canonical row from spoke-generate.md.

### E024 — Generate spoke Phase 2 step numbering not monotonically increasing

- **Severity:** critical
- **Scripts:** validate-skill.sh
- **Check:** For each of the 4 generate spoke files, all `### Step N:` headings within Phase 2 must have strictly increasing N values. JS/TS spokes have 6 steps; Python/Java/Go spokes have 7 steps. Detects step numbering regressions from incorrect edits.
- **Validates:** `references/spoke-generate*.md` → Phase 2 step headings
- **Remediation:** Renumber the `### Step N:` headings in the spoke's Phase 2 section so they increase from 1 without gaps or duplicates. Verify against the canonical step count (6 for JS/TS, 7 for Python/Java/Go).

### E025 — Generate spoke Metrics Update section does not reference pipeline-shared.md

- **Severity:** warning
- **Scripts:** validate-skill.sh
- **Check:** For each of the 4 generate spoke files, the Metrics Update section must reference `pipeline-shared.md` rather than containing the full inline content. This enforces the single-source-of-truth pattern for shared pipeline sections.
- **Validates:** `references/spoke-generate*.md` → Metrics Update section → `references/generate/pipeline-shared.md`
- **Remediation:** Replace the full Metrics Update section with a one-liner reference: `> **Shared section:** See Metrics Update Core in \`references/generate/pipeline-shared.md\`. Ensure the shared content exists in pipeline-shared.md under the heading "Metrics Update Core".

---

## Usage in Validation Scripts

The two validation scripts use this error code taxonomy as follows:

### validate-skill.sh

Runs 8 domains (Domains 1–8). Does not include E004b, E012b, E012c, E012d which are unique to this script. Uses stricter E017 bounds (200–310 lines).

1. **Load** the error code catalog from `references/error-codes.md`.
2. **Run checks sequentially** by domain:
   - Domain 1: Routing & Index Consistency (E001–E002)
   - Domain 2: Reference Index & File Existence (E003–E004, E004b)
   - Domain 3: Spoke & Generate File Integrity (E005–E006)
   - Domain 4: Detection Engine Structure (E007–E009)
   - Domain 5: Schema Field Coverage (E010–E012, E012b–E012d)
   - Domain 6: Template Completeness (E013)
   - Domain 7: SKILL.md Integrity (E015–E017, bounds 200–310)
   - Domain 8: Generate Spoke Behavioral Consistency (E022–E025)
3. **Report each finding** using the error code, e.g.: `E007 (critical): detection-engine.md contains Phase 3 heading`.
4. **Exit with code 0** if no critical errors are found (warnings such as E017 are logged but do not block).
5. **Exit with code 1** if any critical error is found.
6. **Output a summary** with counts: `X passed, Y critical, Z warnings out of N checks`.

### validate-plugin.sh

Runs 8 domains (Domains 1–8). Does not include E004b, E012b–E012d. Uses relaxed E017 bounds (180–325 lines).

1. **Load** the error code catalog from `references/error-codes.md`.
2. **Run checks sequentially** by domain:
   - Domain 1: Routing & Index Consistency (E001–E002)
   - Domain 2: Reference Index & File Existence (E003–E004)
   - Domain 3: Spoke & Generate File Integrity (E005–E006)
   - Domain 4: Detection Engine Structure (E007–E009)
   - Domain 5: Schema Field Coverage (E010–E012)
   - Domain 6: Template Completeness (E013)
   - Domain 7: SKILL.md Integrity (E015–E017, bounds 180–325)
   - Domain 8: Dashboard & JUnit Cross-Cutting (E018–E021)
3. **Report each finding** using the error code, e.g.: `E018 (critical): dashboard.html template exists and non-empty`.
4. **Exit with code 0** if no critical errors are found.
5. **Exit with code 1** if any critical error is found.
6. **Output a summary** with counts: `X passed, Y critical, Z warnings out of N checks`.

## Cross-Reference

- Routing table: `SKILL.md` `<routing>` section
- Reference index: `SKILL.md` `<reference_index>` section or external `references/reference-index.md`
- Config schema: `references/config-schema.md`
- Scan report schema: `references/scan-report-schema.md`
- Stack profile schema: `references/stack-profile-schema.md`
- Metrics schema: `references/metrics-schema.md`
- Schema contract: `references/schema-contract.md`
- Detection engine: `references/detection-engine.md`
- Detection signals: `references/detection-signals.md`
- Templates directory: `references/templates/`
- Dashboard template: `references/templates/dashboard.html`
- Init spoke: `references/spoke-init.md`
- Directory schema: `references/dot-bestest-schema.md`
