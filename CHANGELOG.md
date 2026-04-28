# Changelog

All notable changes to the **bestest** skill are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. Version numbers align with the `version` field in `SKILL.md` frontmatter.

---

## [1.4.0] — 2026-04-27

### Added

- Parallel dispatch architecture (`parallel-dispatch.md`): agent-agnostic 6-platform cascade for multi-agent test generation.
- UX command spokes: `spoke-help.md`, `spoke-explain.md`, `spoke-status.md`, `spoke-version.md` — interactive skill self-service commands.
- Documentation reconciliation: deployed/repo parity + pre-flight protocol references synced across both copies.
- Shared pipeline extraction: `pipeline-shared.md` — 7-phase skeleton eliminating ~60% duplication across language branches.
- Metrics schema integration: `metrics-schema.md` + spoke responsibility matrix across all schema files and spokes.
- `validate-skill.sh` expanded to 304 automated checks across 7 validation domains.

### Changed

- Maturity score improved from 4.3 → 4.4/5.0 (all dimensions ≥ 4.2) per structured 5-dimension re-audit.

### Fixed

- Repair 9 systemic workflow handoff breakages across spokes.
- Scan now writes companion run report for downstream consumption.
- Fix now accepts scan reports as fallback data source.
- Auto-chain HITL gates on scan and run spokes to offer fix/coverage.
- Init recommends `/bestest run` instead of raw test runners.

---

## [1.3.0] — 2026-04-23

### Added

- Confidence scoring algorithm (noisy-OR) in detection-engine.md.
- Generalized conflict detection (category-based per-ecosystem).
- Path validation ordering fix (traversal → canonicalize → boundary).
- Language persistence in StackProfile (selectedLanguage field).
- Schema version contract (schema-contract.md) with validation in 10 consuming spokes.
- Generate spoke decomposition: 4 hub files (≤415 lines) + 24 on-demand sub-files.
- Security hardening: content boundary markers (`BEGIN_UNTRUSTED_SOURCE`) in 9 spokes.
- Taint notice positioned before Context7 fetch in all 6 fetching spokes.
- Complete reference_index: 67 entries across 12 categories.
- `quick_reference.md` extracted for on-demand loading (~68 lines saved).
- `pre-flight-protocol.md`: shared validation patterns reference (271 lines).
- `dot-bestest-schema.md`: complete `.bestest/` directory tree documentation (251 lines).
- `error-codes.md`: error taxonomy (E001–E025, 5 domains).
- `validate-skill.sh`: 266 automated consistency checks across 7 domains.
- GitHub Actions CI workflow for automated skill validation.

---

## [1.2.0] — 2026-04-22

### Added

- Confidence gate in generate routing (R5): warns when language detection confidence < 0.6, offers proceed/manual-select/abort options.
- Multi-language project routing (R10): detects polyglot projects with multiple languages ≥ 0.6 confidence, presents detected languages with scores, supports `--lang` flag for explicit selection.
- Content-boundary markers (R1): `<!-- BEGIN_UNTRUSTED_SOURCE -->` / `<!-- END_UNTRUSTED_SOURCE -->` HTML comment markers around source file read instructions in all generate spokes to mitigate indirect prompt injection.
- State corruption handling (R4): JSON validation blocks before `.bestest/state/*.json` reads across 7 spoke files, with 3-option recovery (regenerate/manual fix/abort).
- Version compatibility check (R15): compares `.bestest/config.yaml` version to SKILL.md frontmatter version in `init` and `doctor` spokes, warns on mismatch.
- `README.md` — user-facing documentation covering installation, quick start, supported languages, commands, and architecture.

### Fixed

- Auto-commit clarification (R6): renamed "Auto-commit criteria" to "Write-to-disk criteria" in all generate spokes with explicit note that git commits are never made without user approval.
- Spoke-init title (R7): corrected scope from "JS/TS repository" to "multi-language repository (JS/TS, Python, Java, Go)".
- Narrowed HITL principle scope (R11): principle 4 now specifies that human-in-the-loop gates apply to mutating commands only (`init`, `generate`, `fix`, `migrate`, `ci`) — not read-only commands (`scan`, `run`, `config show`, `coverage`, `report`, `doctor`).

---

## [1.1.0] — 2026-04-22

### Added

- Skill-level versioning: `version: "1.1.0"` in SKILL.md YAML frontmatter.
- `schemaVersion: "1.1"` top-level field in `stack-profile-schema.md` and `scan-report-schema.md` JSON shapes.
- `CHANGELOG.md` — this file.
- `CONTRIBUTING.md` — spoke template guide and language-addition guide for contributors.

### Fixed

- Removed phantom references (`testing-strategies.md`, `coverage-standards.md`) from SKILL.md `reference_index`. These files were listed but never existed on disk.
- Filled JS/TS decision tree gap for the 20–50 file range (`js-ts-decision-tree.md`).
- Changed fix spoke default classification from `test_bug` to `unknown` (`spoke-fix.md`).
- Harmonized flakiness signal identifiers between `spoke-scan.md` and `scan-report-schema.md`.
- Added report rotation config (`max_retained`) to `config-schema.md` and rotation logic to `spoke-scan.md`.

---

## [1.0.0] — 2026-04-18

### Added

- Initial release of the bestest skill.
- Stack detection engine with 80+ signals across 12 categories.
- Framework decision trees for JS/TS, Python, Java, and Go.
- Command spokes: `init`, `config`, `scan`, `generate`, `run`, `fix`, `coverage`, `report`, `doctor`, `expand`, `migrate`, `ci`.
- Context7 integration for version-specific framework documentation.
- Scan report schema with anti-pattern detection, flaky test identification, coverage gap analysis, and test inventory.
- StackProfile schema with confidence scores and evidence arrays.
- Migration support: Jest → Vitest, JUnit 4 → JUnit 5, Cypress → Playwright.
- CI pipeline generation for GitHub Actions, GitLab CI, and Jenkins.
